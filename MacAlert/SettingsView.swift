import SwiftUI
import EventKit

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
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.soundVolume = UserDefaults.standard.object(forKey: "soundVolume") as? Double ?? 0.7
        self.selectedSound = UserDefaults.standard.string(forKey: "selectedSound") ?? "Ping"
        self.personalMeetingLinks = UserDefaults.standard.dictionary(forKey: "personalMeetingLinks") as? [String: String] ?? [:]
        self.includeReminders = UserDefaults.standard.object(forKey: "includeReminders") as? Bool ?? false
        self.appearancePreference = UserDefaults.standard.string(forKey: "appearancePreference") ?? "system"
    }
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

            Section("License") {
                Text("MIT License — free to use, modify, and distribute.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
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
            }

            Section {
                Toggle("Include Apple Reminders", isOn: $settings.includeReminders)
            } header: {
                Text("Reminders")
            } footer: {
                Text("Show full-screen alerts for reminders with due dates. Requires Reminders access.")
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

    /// Accepts web URLs plus the meeting schemes Reveille already detects.
    private var urlIsValid: Bool {
        let trimmed = newLinkURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https", "facetime"].contains(scheme)
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
