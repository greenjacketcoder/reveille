import SwiftUI
import EventKit
import ServiceManagement

class SettingsManager: ObservableObject {
    @Published var syncInterval: Int {
        didSet {
            UserDefaults.standard.set(syncInterval, forKey: "syncInterval")
        }
    }

    @Published var alertMinutesBefore: Int {
        didSet {
            UserDefaults.standard.set(alertMinutesBefore, forKey: "alertMinutesBefore")
        }
    }

    /// How long snooze defers an alert, in minutes.
    @Published var snoozeMinutes: Int {
        didSet {
            UserDefaults.standard.set(snoozeMinutes, forKey: "snoozeMinutes")
        }
    }

    /// Whether Join opens the provider's desktop app (when one exists and is
    /// installed) instead of the browser. Falls back to the browser
    /// automatically when there's no native equivalent.
    @Published var openInNativeApp: Bool {
        didSet {
            UserDefaults.standard.set(openInNativeApp, forKey: "openInNativeApp")
        }
    }

    /// Opt-in system-wide shortcut that joins the current or next meeting.
    /// Off by default — a global hotkey is intrusive enough that it should be
    /// a deliberate choice.
    @Published var joinHotKeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(joinHotKeyEnabled, forKey: "joinHotKeyEnabled")
            NotificationCenter.default.post(name: .joinHotKeyChanged, object: nil)
        }
    }

    /// Which preset shortcut is used (see JoinShortcut.all).
    @Published var joinShortcutID: String {
        didSet {
            UserDefaults.standard.set(joinShortcutID, forKey: "joinShortcutID")
            NotificationCenter.default.post(name: .joinHotKeyChanged, object: nil)
        }
    }

    /// Whether Reveille registers itself to start at login. Backed by
    /// SMAppService rather than a UserDefault — the system is the source of
    /// truth (the user can also toggle it in System Settings > General >
    /// Login Items), so we read/write through it directly.
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue else { return }
            do {
                if launchAtLogin {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                // Revert the toggle if the system rejected the change, so the
                // UI keeps reflecting the actual login-item state.
                NSLog("Reveille: failed to update login item: \(error.localizedDescription)")
                DispatchQueue.main.async { self.launchAtLogin = (SMAppService.mainApp.status == .enabled) }
            }
        }
    }

    @Published var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled")
        }
    }

    @Published var soundVolume: Double {
        didSet {
            UserDefaults.standard.set(soundVolume, forKey: "soundVolume")
        }
    }

    @Published var selectedSound: String {
        didSet {
            UserDefaults.standard.set(selectedSound, forKey: "selectedSound")
        }
    }

    @Published var personalMeetingLinks: [String: String] {
        didSet {
            UserDefaults.standard.set(personalMeetingLinks, forKey: "personalMeetingLinks")
        }
    }

    @Published var includeReminders: Bool {
        didSet {
            UserDefaults.standard.set(includeReminders, forKey: "includeReminders")
        }
    }

    /// Whether the menu bar shows the next event's title + countdown next to
    /// the icon, or just the icon alone.
    @Published var showMenuBarCountdown: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarCountdown, forKey: "showMenuBarCountdown")
            NotificationCenter.default.post(name: .menuBarDisplayChanged, object: nil)
        }
    }

    /// "system" | "light" | "dark" — applied app-wide via NSApp.appearance,
    /// so alerts, Preferences, and Quick Add all follow it together.
    @Published var appearancePreference: String {
        didSet {
            UserDefaults.standard.set(appearancePreference, forKey: "appearancePreference")
            SettingsManager.applyAppearance(appearancePreference)
        }
    }

    static func applyAppearance(_ preference: String) {
        switch preference {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil  // follow the system
        }
    }

    init() {
        self.syncInterval = UserDefaults.standard.object(forKey: "syncInterval") as? Int ?? 60
        self.alertMinutesBefore = UserDefaults.standard.object(forKey: "alertMinutesBefore") as? Int ?? 5
        self.snoozeMinutes = UserDefaults.standard.object(forKey: "snoozeMinutes") as? Int ?? 2
        self.openInNativeApp = UserDefaults.standard.object(forKey: "openInNativeApp") as? Bool ?? false
        self.joinHotKeyEnabled = UserDefaults.standard.object(forKey: "joinHotKeyEnabled") as? Bool ?? false
        self.joinShortcutID = UserDefaults.standard.string(forKey: "joinShortcutID") ?? JoinShortcut.default.id
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.soundVolume = UserDefaults.standard.object(forKey: "soundVolume") as? Double ?? 0.7
        self.selectedSound = UserDefaults.standard.string(forKey: "selectedSound") ?? "Ping"
        self.personalMeetingLinks = UserDefaults.standard.dictionary(forKey: "personalMeetingLinks") as? [String: String] ?? [:]
        self.includeReminders = UserDefaults.standard.object(forKey: "includeReminders") as? Bool ?? false
        self.showMenuBarCountdown = UserDefaults.standard.object(forKey: "showMenuBarCountdown") as? Bool ?? true
        self.appearancePreference = UserDefaults.standard.string(forKey: "appearancePreference") ?? "system"
    }
}

extension Notification.Name {
    /// Posted when the menu-bar display preference changes, so the
    /// AppDelegate can refresh the status item immediately.
    static let menuBarDisplayChanged = Notification.Name("menuBarDisplayChanged")

    /// Posted when the global join shortcut is enabled/disabled or changed,
    /// so the AppDelegate can re-register it.
    static let joinHotKeyChanged = Notification.Name("joinHotKeyChanged")
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @State private var selectedTab: String

    init(settings: SettingsManager, initialTab: String = "general") {
        self.settings = settings
        self._selectedTab = State(initialValue: initialTab)
    }

    let availableSounds = ["Ping", "Glass", "Submarine", "Hero", "Tink", "Pop", "Purr"]

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Label("General", systemImage: "gear")
                    .tag("general")
                Label("Sounds & Alerts", systemImage: "speaker.wave.2")
                    .tag("sounds")
                Label("Meeting Links", systemImage: "link")
                    .tag("links")
                Label("Calendars", systemImage: "calendar")
                    .tag("calendars")
                Label("About", systemImage: "info.circle")
                    .tag("about")
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            Group {
                switch selectedTab {
                case "general":
                    GeneralSettingsView(settings: settings)
                case "sounds":
                    SoundsSettingsView(settings: settings, availableSounds: availableSounds)
                case "links":
                    MeetingLinksView(settings: settings)
                case "calendars":
                    CalendarsSettingsView()
                case "about":
                    AboutSettingsView()
                default:
                    Text("Select a setting")
                }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
    }
}

struct AboutSettingsView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    // The actual app icon, so this stays in sync with branding
                    // instead of hardcoding an SF Symbol stand-in.
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reveille")
                            .font(.title2)
                            .bold()
                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Free, open-source meeting alerts. No accounts, no telemetry.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Links") {
                Button {
                    if let url = URL(string: "https://github.com/greenjacketcoder/reveille") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Button {
                    if let url = URL(string: "https://github.com/greenjacketcoder/reveille/issues") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Report an Issue", systemImage: "exclamationmark.bubble")
                }

                Button {
                    if let url = URL(string: "https://github.com/greenjacketcoder/reveille/blob/main/README.md") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Read the Documentation", systemImage: "doc.text")
                }
            }

            Section {
                AccessRow(symbol: "calendar", tint: .green,
                          text: "Reads your calendars and reminders locally, on this Mac")
                AccessRow(symbol: "person.crop.circle.badge.xmark", tint: .secondary,
                          text: "No account or sign-in — nothing to log into")
                AccessRow(symbol: "chart.bar.xaxis", tint: .secondary,
                          text: "No analytics, tracking, or telemetry of any kind")
                AccessRow(symbol: "network", tint: .blue,
                          text: "Network is used only to check for app updates and to open meeting links you click")
            } header: {
                Text("Privacy")
            } footer: {
                Text("Reveille reads whatever Calendar.app already has synced. Your calendar data never leaves your Mac through Reveille.")
            }

            Section("License") {
                Text("MIT License — free to use, modify, and distribute.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

/// A single line in the About tab's plain-language "what Reveille accesses"
/// list. Kept factual and checkable rather than marketing.
private struct AccessRow: View {
    let symbol: String
    let tint: Color
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .foregroundColor(tint)
                .frame(width: 18)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer(minLength: 0)
        }
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $settings.appearancePreference) {
                    Text("Match System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("General") {
                Toggle("Launch Reveille at login", isOn: $settings.launchAtLogin)
            }

            Section("Syncing") {
                Picker("Check calendars every", selection: $settings.syncInterval) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("3 minutes").tag(180)
                    Text("5 minutes").tag(300)
                }

                if settings.syncInterval == 30 {
                    Label("Fast sync may use more battery", systemImage: "battery.25")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section("Alerts") {
                Picker("Alert before meeting", selection: $settings.alertMinutesBefore) {
                    Text("1 minute").tag(1)
                    Text("3 minutes").tag(3)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }

                Picker("Snooze for", selection: $settings.snoozeMinutes) {
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }
            }

            Section {
                Picker("Open meetings in", selection: $settings.openInNativeApp) {
                    Text("Browser").tag(false)
                    Text("Desktop app").tag(true)
                }
                .pickerStyle(.inline)

                Toggle("Global shortcut to join", isOn: $settings.joinHotKeyEnabled)

                if settings.joinHotKeyEnabled {
                    Picker("Shortcut", selection: $settings.joinShortcutID) {
                        ForEach(JoinShortcut.all) { shortcut in
                            Text(shortcut.label).tag(shortcut.id)
                        }
                    }
                }
            } header: {
                Text("Joining")
            } footer: {
                Text("Desktop app applies to Zoom, Microsoft Teams, and Jitsi. Other providers, or links without the app installed, always open in your browser.\n\nThe global shortcut joins the meeting that's running now, or the next one with a link — from any app.")
            }

            Section {
                Toggle("Include Apple Reminders", isOn: $settings.includeReminders)
            } header: {
                Text("Reminders")
            } footer: {
                Text("Show full-screen alerts for reminders with due dates. Requires Reminders access.")
            }

            Section {
                Toggle("Show next meeting in the menu bar", isOn: $settings.showMenuBarCountdown)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Display the next event's title and a live countdown next to the icon. Turn off for just the icon.")
            }
        }
        .formStyle(.grouped)
    }
}

struct SoundsSettingsView: View {
    @ObservedObject var settings: SettingsManager
    let availableSounds: [String]

    var body: some View {
        Form {
            Section("Alert Sound") {
                Toggle("Play sound with alerts", isOn: $settings.soundEnabled)

                if settings.soundEnabled {
                    HStack {
                        Picker("Sound", selection: $settings.selectedSound) {
                            ForEach(availableSounds, id: \.self) { sound in
                                Text(sound).tag(sound)
                            }
                        }

                        Button {
                            playPreview()
                        } label: {
                            Label("Preview", systemImage: "play.fill")
                        }
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.secondary)
                        Slider(value: $settings.soundVolume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.secondary)
                        Text("\(Int(settings.soundVolume * 100))%")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Preview at the configured alert volume, so what you hear here is
    /// what an actual alert will sound like.
    private func playPreview() {
        if let sound = NSSound(named: settings.selectedSound) {
            sound.volume = Float(settings.soundVolume)
            sound.play()
        }
    }
}

struct MeetingLinksView: View {
    @ObservedObject var settings: SettingsManager
    @State private var newLinkName = ""
    @State private var newLinkURL = ""

    /// Saved links open in the browser on one click, so require https (or
    /// FaceTime's scheme) - plain http would send meeting access over
    /// cleartext and is never what a real meeting provider uses.
    private var urlIsValid: Bool {
        let trimmed = newLinkURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return false }
        return ["https", "facetime"].contains(scheme)
    }

    private var canAdd: Bool {
        !newLinkName.trimmingCharacters(in: .whitespaces).isEmpty && urlIsValid
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $newLinkName, prompt: Text("e.g. My Zoom Room"))
                TextField("URL", text: $newLinkURL, prompt: Text("https://zoom.us/j/…"))
                    .onSubmit { addLink() }

                HStack {
                    if !newLinkURL.isEmpty && !urlIsValid {
                        Label("Enter a valid link starting with https://", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Button("Add Link") { addLink() }
                        .disabled(!canAdd)
                        .keyboardShortcut(.defaultAction)
                }
            } header: {
                Text("Add New Link")
            } footer: {
                Text("Saved links appear in the menu bar and can auto-fill the Quick Add Meeting form.")
            }

            Section("Saved Links") {
                if settings.personalMeetingLinks.isEmpty {
                    Label("No saved links yet", systemImage: "link.badge.plus")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(settings.personalMeetingLinks.keys.sorted()), id: \.self) { key in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key)
                                Text(settings.personalMeetingLinks[key] ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button {
                                if let url = URL(string: settings.personalMeetingLinks[key] ?? "") {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "arrow.up.forward.square")
                            }
                            .buttonStyle(.plain)
                            .help("Open link")

                            Button {
                                settings.personalMeetingLinks.removeValue(forKey: key)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Delete link")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addLink() {
        guard canAdd else { return }
        settings.personalMeetingLinks[newLinkName.trimmingCharacters(in: .whitespaces)] =
            newLinkURL.trimmingCharacters(in: .whitespaces)
        newLinkName = ""
        newLinkURL = ""
    }
}

struct CalendarsSettingsView: View {
    @State private var calendars: [EKCalendar] = []

    var body: some View {
        Form {
            Section("Connected Calendars") {
                if calendars.isEmpty {
                    Label("Loading calendars…", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(calendars, id: \.calendarIdentifier) { calendar in
                        HStack {
                            Circle()
                                .fill(Color(calendar.color))
                                .frame(width: 12, height: 12)
                            Text(calendar.title)
                            Spacer()
                            Text(calendar.source.title)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Reveille reads whatever your Mac's Calendar app already has synced — it doesn't sync accounts itself.")
                    Text("• iCloud calendars: typically sync within about a minute")
                    Text("• Google/Outlook calendars: usually sync within a few minutes, depending on how they were added (Internet Accounts vs. a native app)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } header: {
                Text("Sync Timing")
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("If a calendar or its events aren't showing up:")
                    Text("1. Open Calendar.app and confirm the calendar is enabled and syncing there first")
                    Text("2. Check System Settings > Privacy & Security > Calendars to confirm Reveille has access")
                    Text("3. If you enabled Reminders alerts, also check the Reminders row in that same Privacy pane")
                    Text("4. Still stuck? Quit and relaunch Reveille — it re-reads calendars fresh on launch")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            } header: {
                Text("Troubleshooting")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadCalendars()
        }
    }

    private func loadCalendars() {
        let manager = CalendarManager()
        calendars = manager.getCalendars()
    }
}
