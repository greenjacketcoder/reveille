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
            button.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "Reveille")
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

            let window = NSWindow(contentViewController: hostingController)
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

            let hostingController = NSHostingController(rootView: reminderAlert)

            let window = NSWindow(contentViewController: hostingController)
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
        if settingsWindow != nil {
            settingsWindow?.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(settings: settings)
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
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "s" {
                delegate?.handleAlertAction(.snooze, for: self.event)
                return
            } else if event.keyCode == 36 {
                delegate?.handleAlertAction(.join, for: self.event)
                return
            }
        }

        if event.keyCode == 53 {
            delegate?.handleAlertAction(.dismiss, for: self.event)
            return
        }

        super.keyDown(with: event)
    }
}
