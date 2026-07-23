import SwiftUI
import EventKit
import AVFoundation
import Sparkle

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
    var alertWindow: NSWindow?
    var settingsWindow: NSWindow?
    var quickEventWindow: NSWindow?
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

        setupMenuBar()

        calendarManager = CalendarManager()
        requestCalendarAccess()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(syncIntervalChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        handleDebugScreenshotArgument()
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
            case "meeting-alert":
                let fakeEvent = EKEvent(eventStore: EKEventStore())
                fakeEvent.title = "Product Sync"
                fakeEvent.startDate = Date().addingTimeInterval(240)
                fakeEvent.endDate = Date().addingTimeInterval(1800)
                fakeEvent.location = "https://zoom.us/j/1234567890"
                fakeEvent.notes = "Weekly product sync with the team."
                self.showAlert(for: fakeEvent)
            case "reminder-alert":
                let fakeReminder = EKReminder(eventStore: EKEventStore())
                fakeReminder.title = "Follow up with client"
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

    /// Shows retry progress as text next to the menu bar bell icon, or
    /// clears it (nil) once access is resolved.
    private func setRetryStatus(_ text: String?) {
        statusItem?.button?.title = text ?? ""
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
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Next Meeting", action: #selector(showNextMeeting), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quick Add Meeting...", action: #selector(showQuickEvent), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())

        let linksMenu = NSMenu()
        if !settings.personalMeetingLinks.isEmpty {
            for (name, url) in settings.personalMeetingLinks.sorted(by: { $0.key < $1.key }) {
                let item = NSMenuItem(title: name, action: #selector(openPersonalLink(_:)), keyEquivalent: "")
                item.representedObject = url
                linksMenu.addItem(item)
            }
        } else {
            linksMenu.addItem(NSMenuItem(title: "No saved links", action: nil, keyEquivalent: ""))
        }

        let linksMenuItem = NSMenuItem(title: "Personal Meeting Links", action: nil, keyEquivalent: "")
        linksMenuItem.submenu = linksMenu
        menu.addItem(linksMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdatesItem.target = updaterController
        menu.addItem(checkForUpdatesItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Reveille", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
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
            if !hasShownAlert(for: event.eventIdentifier) {
                showAlert(for: event)
                markAlertShown(for: event.eventIdentifier)
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

    func showAlert(for event: EKEvent) {
        DispatchQueue.main.async {
            if self.alertWindow != nil {
                self.alertWindow?.close()
            }

            if self.settings.soundEnabled {
                self.playAlertSound()
            }

            let meetingAlert = MeetingAlertView(event: event) { action in
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

            if let screen = NSScreen.main {
                window.setFrame(screen.frame, display: true)
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

            let reminderAlert = ReminderAlertView(reminder: reminder) { action in
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

            if let screen = NSScreen.main {
                window.setFrame(screen.frame, display: true)
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
                NSWorkspace.shared.open(url)
            }
            closeAlert()
        case .snooze:
            closeAlert()
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
                self.shownAlerts.remove(event.eventIdentifier)
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
        let urlPatterns = [
            "https://zoom.us/",
            "https://meet.google.com/",
            "https://teams.microsoft.com/",
            "https://discord.gg/",
            "https://slack.com/",
            "facetime://"
        ]

        if let url = event.url, urlPatterns.contains(where: { url.absoluteString.contains($0) }) {
            return url
        }

        let searchText = (event.notes ?? "") + " " + (event.location ?? "")

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: searchText, range: NSRange(searchText.startIndex..., in: searchText))

        for match in matches ?? [] {
            if let range = Range(match.range, in: searchText),
               let url = URL(string: String(searchText[range])),
               urlPatterns.contains(where: { url.absoluteString.contains($0) }) {
                return url
            }
        }

        return nil
    }

    @objc func showNextMeeting() {
        guard let events = calendarManager?.getUpcomingEvents(withinMinutes: 60) else {
            showNoMeetingsAlert()
            return
        }

        if let nextEvent = events.first {
            let alert = NSAlert()
            alert.messageText = "Next Meeting"
            alert.informativeText = """
            \(nextEvent.title ?? "Untitled")
            \(formatEventTime(nextEvent))
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            showNoMeetingsAlert()
        }
    }

    func showNoMeetingsAlert() {
        let alert = NSAlert()
        alert.messageText = "No Upcoming Meetings"
        alert.informativeText = "You have no meetings in the next hour."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func formatEventTime(_ event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let start = formatter.string(from: event.startDate)
        let end = formatter.string(from: event.endDate)
        return "\(start) - \(end)"
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) {
                self.shownAlerts.remove(identifier)
            }
        case .dismiss:
            closeAlert()
        case .join:
            // Not applicable to reminders; meetings use .join instead.
            break
        }
    }

    @objc func openPersonalLink(_ sender: NSMenuItem) {
        if let urlString = sender.representedObject as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
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
        window.setContentSize(NSSize(width: 700, height: 500))
        window.center()
        window.collectionBehavior = [.canJoinAllSpaces]

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

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
