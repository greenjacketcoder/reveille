import SwiftUI
import EventKit
import AVFoundation
import Sparkle
import MeetingLink

@main
struct MacAlertApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var calendarManager: CalendarManager?
    var settings = SettingsManager()
    var timer: Timer?
    /// Fires every ~30s to refresh the menu-bar countdown text. Separate from
    /// `timer` (the alert-check timer), which can be as slow as 5 minutes —
    /// too coarse for a live "in 4m" countdown.
    var menuBarTimer: Timer?
    /// Set while access retry is in progress; suppresses the countdown so the
    /// two don't fight over the status item's title.
    private var retryStatusText: String?
    var alertWindow: NSWindow?
    var settingsWindow: NSWindow?
    var quickEventWindow: NSWindow?
    /// The menu-bar agenda dropdown, shown on left-click of the status item.
    var agendaPopover: NSPopover?

    /// Owns the optional system-wide "join now" shortcut.
    private let joinHotKey = HotKeyManager()

    /// Debug-screenshot only: force light/dark on alert windows so both
    /// schemes can be captured regardless of the system appearance.
    var debugForcedAppearance: NSAppearance?
    // Local monitor for the alert window's keyboard shortcuts. Using a
    // monitor rather than relying on NSHostingController.keyDown, since
    // SwiftUI's own view hierarchy can intercept key events at a lower
    // level and never forward unhandled ones up the responder chain to
    // the hosting view controller - this sidesteps that entirely by
    // intercepting before normal AppKit dispatch happens.
    var alertKeyMonitor: Any?

    // Sparkle's controller owns update checking, downloading, EdDSA signature
    // verification, and installation. `startingUpdater: true` means it begins
    // its scheduled background checks (per SUScheduledCheckInterval in
    // Info.plist) as soon as this is created.
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    // Retry state for calendar access acquisition. Access can be granted a
    // moment after the prompt (or later, via System Settings) without the
    // app restarting, so we back off and retry a few times before giving up.
    private var accessRetryCount = 0
    private let maxAccessRetries = 3
    private let accessRetryIntervals: [TimeInterval] = [5, 15, 45]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Apply the saved appearance preference (System/Light/Dark) app-wide
        // before any windows exist.
        SettingsManager.applyAppearance(settings.appearancePreference)

        setupMenuBar()
        installMinimalMainMenu()

        calendarManager = CalendarManager.shared
        requestCalendarAccess()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncIntervalChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarDisplayChanged),
            name: .menuBarDisplayChanged,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(joinHotKeyChanged),
            name: .joinHotKeyChanged,
            object: nil
        )

        startMenuBarTimer()
        refreshJoinHotKey()

        handleDebugScreenshotArgument()
    }

    /// Replaces SwiftUI's default application menu (Edit / View / Window /
    /// Help — all meaningless for a menu-bar-only app) with just an app menu.
    /// Showing an alert activates the app, at which point macOS displays this
    /// menu bar; trimming it to the essentials keeps that far less intrusive.
    private func installMinimalMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let prefs = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
        prefs.target = self
        appMenu.addItem(prefs)
        appMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Reveille", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Global join shortcut

    @objc private func joinHotKeyChanged() {
        refreshJoinHotKey()
    }

    /// Registers or tears down the global shortcut to match the current
    /// preference. If the system refuses the combination (another app already
    /// owns it), tell the user rather than leaving a dead shortcut.
    private func refreshJoinHotKey() {
        guard settings.joinHotKeyEnabled else {
            joinHotKey.unregister()
            return
        }

        let shortcut = JoinShortcut.named(settings.joinShortcutID)
        let ok = joinHotKey.register(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
            self?.joinCurrentOrNextMeeting()
        }

        if !ok {
            let alert = NSAlert()
            alert.messageText = "Shortcut Unavailable"
            alert.informativeText = "\(shortcut.label) is already in use by another app. Pick a different shortcut in Preferences → General."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    /// Joins the meeting that's running now, or the soonest upcoming one with a
    /// link. If nothing is joinable, shows the agenda popover instead — that
    /// gives visible feedback and useful context rather than doing nothing.
    private func joinCurrentOrNextMeeting() {
        let events = calendarManager?.getTodaysEvents() ?? []
        let windows = events.map {
            JoinTarget.Window(start: $0.startDate, end: $0.endDate, hasLink: findMeetingURL(in: $0) != nil)
        }

        if let index = JoinTarget.index(in: windows, now: Date()),
           let url = findMeetingURL(in: events[index]) {
            openMeeting(url)
        } else {
            showAgendaPopover()
        }
    }

    // MARK: - Menu bar countdown

    /// Refreshes the next-meeting countdown roughly every 30s. The alert-check
    /// timer is too coarse (up to 5 min) for a smooth countdown.
    private func startMenuBarTimer() {
        menuBarTimer?.invalidate()
        menuBarTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.updateMenuBarTitle()
        }
        menuBarTimer?.tolerance = 5
        updateMenuBarTitle()
    }

    @objc private func menuBarDisplayChanged() {
        updateMenuBarTitle()
    }

    /// Sets the status item's title from the next event, unless retry status
    /// is showing (which takes priority) or the user turned the countdown off.
    private func updateMenuBarTitle() {
        guard let button = statusItem?.button else { return }

        // Retry status wins while access is being acquired.
        if let retry = retryStatusText {
            button.title = retry.isEmpty ? "" : " " + retry
            return
        }

        guard settings.showMenuBarCountdown, let next = calendarManager?.getNextEvent() else {
            button.title = ""
            return
        }

        button.title = " " + menuBarString(for: next)
    }

    /// "Standup · 4m" style label. Delegates to the tested AlertScheduling
    /// logic in the MeetingLink package.
    private func menuBarString(for event: EKEvent) -> String {
        let mins = Int(event.startDate.timeIntervalSinceNow / 60)
        return AlertScheduling.menuBarString(title: event.title, minutesUntilStart: mins)
    }

    /// Lets us pop open any window on demand for screenshotting/UX review,
    /// without waiting on a real calendar event or clicking through the menu
    /// bar. Launch with e.g. `--debug-screenshot=meeting-alert`. Not wired
    /// into any shipped UI path.
    private func handleDebugScreenshotArgument() {
        guard let modeArg = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--debug-screenshot=") }) else {
            return
        }
        let mode = modeArg.replacingOccurrences(of: "--debug-screenshot=", with: "")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let parts = mode.split(separator: ":", maxSplits: 1).map(String.init)
            let base = parts.first ?? mode
            let arg = parts.count > 1 ? parts[1] : nil

            switch base {
            case "preferences":
                self.openPreferencesWindow(initialTab: arg ?? "general")
            case "quickadd":
                self.showQuickEvent()
            case "agenda":
                self.showAgendaPopover()
            case "meeting-alert":
                // Fake event + agenda mirroring the design mock, so screenshots
                // show the sidebar populated the way real usage would.
                let store = EKEventStore()
                let cal = Calendar.current
                let today = cal.startOfDay(for: Date())

                func fake(_ title: String, hour: Int, minute: Int, durationMin: Int) -> EKEvent {
                    let e = EKEvent(eventStore: store)
                    e.title = title
                    e.startDate = cal.date(bySettingHour: hour, minute: minute, second: 0, of: today)
                    e.endDate = e.startDate.addingTimeInterval(TimeInterval(durationMin * 60))
                    return e
                }

                let nowComp = cal.dateComponents([.hour, .minute], from: Date())
                let nextEvent = EKEvent(eventStore: store)
                nextEvent.title = "Design Review — Q3 Roadmap"
                nextEvent.startDate = Date().addingTimeInterval(120)
                nextEvent.endDate = nextEvent.startDate.addingTimeInterval(1800)
                nextEvent.location = "https://meet.google.com/hwq-rfzp"
                nextEvent.notes = "Walking the Q3 roadmap with the design team."

                let agenda = [
                    fake("Standup", hour: max((nowComp.hour ?? 10) - 1, 0), minute: 0, durationMin: 15),
                    nextEvent,
                    fake("1:1 · Jordan", hour: min((nowComp.hour ?? 10) + 3, 22), minute: 30, durationMin: 30),
                    fake("Ship review", hour: min((nowComp.hour ?? 10) + 6, 23), minute: 0, durationMin: 30),
                ]

                if arg == "light" || arg == "dark" {
                    self.debugForcedAppearance = NSAppearance(named: arg == "dark" ? .darkAqua : .aqua)
                }
                self.showAlert(for: nextEvent, agendaOverride: agenda)
            case "reminder-alert":
                let fakeReminder = EKReminder(eventStore: EKEventStore())
                fakeReminder.title = "Follow up with client"
                if arg == "light" || arg == "dark" {
                    self.debugForcedAppearance = NSAppearance(named: arg == "dark" ? .darkAqua : .aqua)
                }
                self.showReminderAlert(for: fakeReminder)
            default:
                break
            }
        }
    }

    private func requestCalendarAccess() {
        calendarManager?.requestAccess { granted in
            DispatchQueue.main.async {
                if granted {
                    self.accessRetryCount = 0
                    self.setRetryStatus(nil)
                    if self.settings.includeReminders {
                        self.calendarManager?.requestRemindersAccess { _ in }
                    }
                    self.startMonitoring()
                } else {
                    self.retryCalendarAccess()
                }
            }
        }
    }

    private func retryCalendarAccess() {
        guard accessRetryCount < maxAccessRetries else {
            setRetryStatus(nil)
            showAccessDeniedAlert()
            return
        }

        let attempt = accessRetryCount + 1
        setRetryStatus("Retrying \(attempt)/\(maxAccessRetries)...")

        let delay = accessRetryIntervals[accessRetryCount]
        accessRetryCount += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.requestCalendarAccess()
        }
    }

    /// Shows retry progress next to the menu bar icon, or clears it (nil)
    /// once access is resolved. Routes through updateMenuBarTitle so it
    /// coordinates with the countdown rather than overwriting it directly.
    private func setRetryStatus(_ text: String?) {
        retryStatusText = text
        updateMenuBarTitle()
    }

    @objc func syncIntervalChanged() {
        timer?.invalidate()
        startMonitoring()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.accessibilityDescription = "Reveille"
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
        }
    }

    /// Toggles the agenda popover. Left-click shows today's meetings; the
    /// popover itself carries the app actions (Quick Add, Settings, updates,
    /// quit) in its footer, so no separate NSMenu is needed.
    @objc private func togglePopover() {
        if let popover = agendaPopover, popover.isShown {
            popover.performClose(nil)
            return
        }
        showAgendaPopover()
    }

    @objc private func statusItemClicked() {
        togglePopover()
    }

    private func showAgendaPopover() {
        guard let button = statusItem?.button else { return }

        let events = calendarManager?.getTodaysEvents() ?? []
        let allDay = calendarManager?.getTodaysAllDayEvents() ?? []
        let tomorrow = calendarManager?.getTomorrowsEvents() ?? []
        let agenda = AgendaView(
            events: events,
            allDayEvents: allDay,
            tomorrowEvents: tomorrow,
            onJoin: { [weak self] event in
                self?.agendaPopover?.performClose(nil)
                if let url = self?.findMeetingURL(in: event) {
                    self?.openMeeting(url)
                }
            },
            onQuickAdd: { [weak self] in
                self?.agendaPopover?.performClose(nil)
                self?.showQuickEvent()
            },
            onPreferences: { [weak self] in
                self?.agendaPopover?.performClose(nil)
                self?.showPreferences()
            },
            onCheckForUpdates: { [weak self] in
                self?.agendaPopover?.performClose(nil)
                self?.updaterController.checkForUpdates(nil)
            },
            onQuit: { NSApplication.shared.terminate(nil) }
        )

        let popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: agenda)
        popover.behavior = .transient  // auto-closes when you click elsewhere
        popover.animates = true
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        agendaPopover = popover
    }

    func startMonitoring() {
        let interval = TimeInterval(settings.syncInterval)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForUpcomingMeetings()
        }
        timer?.tolerance = 5.0

        checkForUpcomingMeetings()
    }

    func checkForUpcomingMeetings() {
        let alertMinutes = settings.alertMinutesBefore

        guard let events = calendarManager?.getUpcomingEvents(withinMinutes: alertMinutes) else { return }

        for event in events {
            let key = alertKey(for: event)
            if !hasShownAlert(for: key) {
                showAlert(for: event)
                markAlertShown(for: key)
            }
        }

        if settings.includeReminders {
            let reminders = calendarManager?.getUpcomingReminders(withinMinutes: alertMinutes) ?? []
            for reminder in reminders {
                let identifier = reminder.calendarItemIdentifier
                if !hasShownAlert(for: identifier) {
                    showReminderAlert(for: reminder)
                    markAlertShown(for: identifier)
                }
            }
        }

        // Keep the menu-bar countdown fresh as events come and go.
        updateMenuBarTitle()
    }

    /// Dedup key for "already alerted this event occurrence." Delegates to the
    /// tested AlertScheduling logic (recurring events share one identifier
    /// across occurrences, so the key combines identifier + start time).
    private func alertKey(for event: EKEvent) -> String {
        AlertScheduling.alertKey(identifier: event.eventIdentifier, start: event.startDate)
    }

    private var shownAlerts = Set<String>()

    private func hasShownAlert(for identifier: String) -> Bool {
        return shownAlerts.contains(identifier)
    }

    private func markAlertShown(for identifier: String) {
        shownAlerts.insert(identifier)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3600) { [weak self] in
            self?.shownAlerts.remove(identifier)
        }
    }

    func showAlert(for event: EKEvent, agendaOverride: [EKEvent]? = nil) {
        DispatchQueue.main.async {
            if self.alertWindow != nil {
                self.alertWindow?.close()
            }

            if self.settings.soundEnabled {
                self.playAlertSound()
            }

            let todaysEvents = agendaOverride ?? self.calendarManager?.getTodaysEvents() ?? []
            let meetingURL = self.findMeetingURL(in: event)

            let meetingAlert = MeetingAlertView(
                event: event,
                todaysEvents: todaysEvents,
                meetingURL: meetingURL,
                snoozeMinutes: self.settings.snoozeMinutes
            ) { action in
                self.handleAlertAction(action, for: event)
            }

            let hostingController = AlertHostingController(rootView: meetingAlert, event: event, delegate: self)

            let window = KeyableAlertWindow(contentViewController: hostingController)
            window.styleMask = [.borderless, .fullSizeContentView]
            window.level = .floating
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.isMovable = false
            window.isReleasedWhenClosed = false
            if let forced = self.debugForcedAppearance {
                window.appearance = forced
            }

            // Always give the window a frame. A nil screen previously meant
            // no frame was set at all, stranding the panel in a corner at its
            // intrinsic size instead of covering the display.
            if let screen = self.alertScreen() {
                window.setFrame(screen.frame, display: true)
            } else {
                window.center()
            }

            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            self.alertWindow = window
            self.installAlertKeyMonitor { [weak self] keyCode, chars in
                guard let self = self else { return false }
                switch keyCode {
                case 36, 76: // Return / keypad Enter
                    self.handleAlertAction(.join, for: event)
                    return true
                case 53: // Escape
                    self.handleAlertAction(.dismiss, for: event)
                    return true
                default:
                    break
                }
                if chars?.lowercased() == "s" {
                    self.handleAlertAction(.snooze, for: event)
                    return true
                }
                return false
            }
        }
    }

    func showReminderAlert(for reminder: EKReminder) {
        DispatchQueue.main.async {
            if self.alertWindow != nil {
                self.alertWindow?.close()
            }

            if self.settings.soundEnabled {
                self.playAlertSound()
            }

            let reminderAlert = ReminderAlertView(reminder: reminder, snoozeMinutes: self.settings.snoozeMinutes) { action in
                self.handleReminderAction(action, for: reminder)
            }

            let hostingController = ReminderAlertHostingController(rootView: reminderAlert, reminder: reminder, delegate: self)

            let window = KeyableAlertWindow(contentViewController: hostingController)
            window.styleMask = [.borderless, .fullSizeContentView]
            window.level = .floating
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            window.isMovable = false
            window.isReleasedWhenClosed = false
            if let forced = self.debugForcedAppearance {
                window.appearance = forced
            }

            // Always give the window a frame. A nil screen previously meant
            // no frame was set at all, stranding the panel in a corner at its
            // intrinsic size instead of covering the display.
            if let screen = self.alertScreen() {
                window.setFrame(screen.frame, display: true)
            } else {
                window.center()
            }

            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            self.alertWindow = window
            self.installAlertKeyMonitor { [weak self] keyCode, chars in
                guard let self = self else { return false }
                switch keyCode {
                case 36, 76: // Return / keypad Enter -> complete
                    self.handleReminderAction(.complete, for: reminder)
                    return true
                case 53: // Escape
                    self.handleReminderAction(.dismiss, for: reminder)
                    return true
                default:
                    break
                }
                switch chars?.lowercased() {
                case "s":
                    self.handleReminderAction(.snooze, for: reminder)
                    return true
                case "o":
                    self.handleReminderAction(.open, for: reminder)
                    return true
                default:
                    return false
                }
            }
        }
    }

    func playAlertSound() {
        if let sound = NSSound(named: settings.selectedSound) {
            sound.volume = Float(settings.soundVolume)
            sound.play()
        }
    }

    func handleAlertAction(_ action: AlertAction, for event: EKEvent) {
        switch action {
        case .join:
            if let url = findMeetingURL(in: event) {
                openMeeting(url)
            }
            closeAlert()
        case .snooze:
            closeAlert()
            // Re-fire precisely after the (smart-capped) snooze interval
            // rather than relying on the next poll. See AlertScheduling.
            let key = alertKey(for: event)
            shownAlerts.remove(key)
            let snooze = AlertScheduling.snoozeDelay(
                chosenMinutes: settings.snoozeMinutes,
                secondsUntilStart: event.startDate.timeIntervalSinceNow
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + snooze) { [weak self] in
                guard let self = self else { return }
                // Only re-alert if it's still upcoming and not already re-shown.
                if event.startDate > Date(), !self.hasShownAlert(for: key) {
                    self.showAlert(for: event)
                    self.markAlertShown(for: key)
                }
            }
        case .dismiss:
            closeAlert()
        case .complete, .open:
            // Not applicable to meetings; reminders use these instead.
            break
        }
    }

    func closeAlert() {
        alertWindow?.close()
        alertWindow = nil
        if let monitor = alertKeyMonitor {
            NSEvent.removeMonitor(monitor)
            alertKeyMonitor = nil
        }
    }

    /// Which screen a full-screen alert should cover, honoring the user's
    /// "Show alerts on" preference.
    ///
    /// The fallback chain matters: NSScreen.main is documented as nil-able
    /// (no active screen — display sleep/wake, lock, reconfiguration), and
    /// callers MUST always get a frame. Previously a nil here meant the window
    /// was never sized or positioned at all, so it kept the panel's intrinsic
    /// 920x570 size at AppKit's default origin and appeared stranded in a
    /// corner instead of covering the display.
    private func alertScreen() -> NSScreen? {
        let preferPrimary = settings.alertDisplayPreference == "primary"

        if preferPrimary, let primary = NSScreen.screens.first {
            return primary
        }

        let mouse = NSEvent.mouseLocation
        if let underPointer = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return underPointer
        }

        return NSScreen.main ?? NSScreen.screens.first
    }

    /// Installs a local keyDown monitor for the currently showing alert
    /// window. `handler` returns true if it handled the key (swallows the
    /// event) or false to let it pass through normally. Replaces any
    /// previously installed monitor first, since only one alert shows at
    /// a time.
    func installAlertKeyMonitor(_ handler: @escaping (UInt16, String?) -> Bool) {
        if let existing = alertKeyMonitor {
            NSEvent.removeMonitor(existing)
        }
        alertKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if handler(event.keyCode, event.charactersIgnoringModifiers) {
                return nil
            }
            return event
        }
    }

    func findMeetingURL(in event: EKEvent) -> URL? {
        // Host-allowlisted matching via MeetingLinkDetector - see its docs.
        // Calendar event contents are untrusted input.
        if let url = event.url, MeetingLinkDetector.isMeetingURL(url) {
            return url
        }

        let searchText = (event.notes ?? "") + " " + (event.location ?? "")

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: searchText, range: NSRange(searchText.startIndex..., in: searchText))

        for match in matches ?? [] {
            if let range = Range(match.range, in: searchText),
               let url = URL(string: String(searchText[range])),
               MeetingLinkDetector.isMeetingURL(url) {
                return url
            }
        }

        return nil
    }

    /// Opens an already-validated meeting link, honoring the "open meetings in"
    /// preference. Falls back to the browser whenever the desktop route isn't
    /// viable: the user prefers the browser, the provider has no native scheme,
    /// or nothing installed claims that scheme. Without that last check,
    /// choosing "Desktop app" without the client installed would make Join
    /// appear to do nothing.
    func openMeeting(_ url: URL) {
        if settings.openInNativeApp,
           let native = NativeAppLink.nativeURL(for: url),
           NSWorkspace.shared.urlForApplication(toOpen: native) != nil {
            NSWorkspace.shared.open(native)
            return
        }
        NSWorkspace.shared.open(url)
    }

    func handleReminderAction(_ action: AlertAction, for reminder: EKReminder) {
        switch action {
        case .complete:
            calendarManager?.completeReminder(reminder)
            closeAlert()
        case .open:
            calendarManager?.openRemindersApp()
            // Don't close the alert here — the user may just be checking
            // context in Reminders.app before deciding to snooze or complete.
        case .snooze:
            closeAlert()
            let identifier = reminder.calendarItemIdentifier
            shownAlerts.remove(identifier)
            let snooze = TimeInterval(settings.snoozeMinutes * 60)
            DispatchQueue.main.asyncAfter(deadline: .now() + snooze) { [weak self] in
                guard let self = self else { return }
                if !self.hasShownAlert(for: identifier) {
                    self.showReminderAlert(for: reminder)
                    self.markAlertShown(for: identifier)
                }
            }
        case .dismiss:
            closeAlert()
        case .join:
            // Not applicable to reminders; meetings use .join instead.
            break
        }
    }

    @objc func showQuickEvent() {
        if quickEventWindow != nil {
            quickEventWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let calendarWrapper = CalendarManagerWrapper()
        let quickEventView = QuickEventView(calendarManager: calendarWrapper, settings: settings)
        let hostingController = NSHostingController(rootView: quickEventView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Quick Add Meeting"
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.center()
        // Release the window (and its whole SwiftUI hierarchy, including the
        // EKEventStore the wrapper creates) when closed, instead of keeping
        // it resident for the app's lifetime. ARC owns it; delegate nils the
        // reference in windowWillClose.
        window.isReleasedWhenClosed = false
        window.delegate = self

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        quickEventWindow = window
    }

    @objc func showPreferences() {
        openPreferencesWindow(initialTab: "general")
    }

    func openPreferencesWindow(initialTab: String) {
        if settingsWindow != nil {
            settingsWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(settings: settings, initialTab: initialTab)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Reveille Preferences"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 560))
        window.center()
        window.collectionBehavior = [.canJoinAllSpaces]
        window.isReleasedWhenClosed = false
        window.delegate = self

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Window lifecycle

extension AppDelegate: NSWindowDelegate {
    /// Release closed windows instead of keeping them resident forever.
    /// Without this, the first open of Preferences or Quick Add retained its
    /// entire SwiftUI hierarchy (hosting controller, views, and the extra
    /// EKEventStore instances some views create) for the app's lifetime,
    /// so memory ratcheted up after each interaction and never came back down.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == settingsWindow {
            settingsWindow = nil
        } else if window == quickEventWindow {
            quickEventWindow = nil
        }
    }
}

extension AppDelegate {

    func showAccessDeniedAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Calendar Access Required"
            alert.informativeText = "Reveille needs access to your calendar to show meeting reminders. Please grant access in System Settings > Privacy & Security > Calendars."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Quit")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
            }
            NSApplication.shared.terminate(nil)
        }
    }
}

class AlertHostingController<Content: View>: NSHostingController<Content> {
    weak var delegate: AppDelegate?
    let event: EKEvent

    init(rootView: Content, event: EKEvent, delegate: AppDelegate) {
        self.event = event
        self.delegate = delegate
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: // Return / keypad Enter
            delegate?.handleAlertAction(.join, for: self.event)
            return
        case 53: // Escape
            delegate?.handleAlertAction(.dismiss, for: self.event)
            return
        default:
            break
        }

        if event.charactersIgnoringModifiers?.lowercased() == "s" {
            delegate?.handleAlertAction(.snooze, for: self.event)
            return
        }

        super.keyDown(with: event)
    }
}

/// Borderless windows default `canBecomeKey`/`canBecomeMain` to false (Apple's
/// own documented behavior, intended for things like tooltips that shouldn't
/// steal keyboard focus). Since our full-screen alert windows are borderless
/// but genuinely need to receive keyboard input (Enter/Esc/S), a plain
/// NSWindow here silently never becomes key and keyDown never fires for
/// anything inside it. This subclass is the standard fix.
class KeyableAlertWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class ReminderAlertHostingController<Content: View>: NSHostingController<Content> {
    weak var delegate: AppDelegate?
    let reminder: EKReminder

    init(rootView: Content, reminder: EKReminder, delegate: AppDelegate) {
        self.reminder = reminder
        self.delegate = delegate
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 76: // Return / keypad Enter -> complete
            delegate?.handleReminderAction(.complete, for: self.reminder)
            return
        case 53: // Escape
            delegate?.handleReminderAction(.dismiss, for: self.reminder)
            return
        default:
            break
        }

        switch event.charactersIgnoringModifiers?.lowercased() {
        case "s":
            delegate?.handleReminderAction(.snooze, for: self.reminder)
        case "o":
            delegate?.handleReminderAction(.open, for: self.reminder)
        default:
            super.keyDown(with: event)
        }
    }
}
