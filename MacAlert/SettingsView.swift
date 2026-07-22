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

    init() {
        self.syncInterval = UserDefaults.standard.object(forKey: "syncInterval") as? Int ?? 60
        self.alertMinutesBefore = UserDefaults.standard.object(forKey: "alertMinutesBefore") as? Int ?? 5
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.soundVolume = UserDefaults.standard.object(forKey: "soundVolume") as? Double ?? 0.7
        self.selectedSound = UserDefaults.standard.string(forKey: "selectedSound") ?? "Ping"
        self.personalMeetingLinks = UserDefaults.standard.dictionary(forKey: "personalMeetingLinks") as? [String: String] ?? [:]
        self.includeReminders = UserDefaults.standard.object(forKey: "includeReminders") as? Bool ?? false
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    @State private var selectedTab = "general"
    @State private var newLinkName = ""
    @State private var newLinkURL = ""

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

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.accentColor.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Reveille")
                        .font(.title2)
                        .bold()
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text("A free, open-source macOS meeting reminder app — full-screen alerts, no accounts, no telemetry.")
                .font(.body)
                .foregroundColor(.secondary)

            Form {
                Section(header: Text("Links")) {
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

                Section(header: Text("License")) {
                    Text("MIT License — free to use, modify, and distribute.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
        .padding()
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager

    var body: some View {
        Form {
            Section(header: Text("Sync Settings")) {
                Picker("Sync Interval:", selection: $settings.syncInterval) {
                    Text("30 seconds (Fast)").tag(30)
                    Text("1 minute").tag(60)
                    Text("3 minutes").tag(180)
                    Text("5 minutes").tag(300)
                }
                .pickerStyle(.inline)

                if settings.syncInterval == 30 {
                    Text("Fast sync may use more battery")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Section(header: Text("Alert Timing")) {
                Picker("Alert before meeting:", selection: $settings.alertMinutesBefore) {
                    Text("1 minute").tag(1)
                    Text("3 minutes").tag(3)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                    Text("15 minutes").tag(15)
                }
            }

            Section(header: Text("Reminders")) {
                Toggle("Include Apple Reminders", isOn: $settings.includeReminders)
                Text("Show alerts for upcoming reminders with due dates")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct SoundsSettingsView: View {
    @ObservedObject var settings: SettingsManager
    let availableSounds: [String]

    var body: some View {
        Form {
            Section(header: Text("Alert Sound")) {
                Toggle("Play sound with alerts", isOn: $settings.soundEnabled)

                if settings.soundEnabled {
                    Picker("Sound:", selection: $settings.selectedSound) {
                        ForEach(availableSounds, id: \.self) { sound in
                            HStack {
                                Text(sound)
                                Spacer()
                                Button(action: { playSound(sound) }) {
                                    Image(systemName: "play.circle")
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .tag(sound)
                        }
                    }
                    .pickerStyle(.inline)

                    HStack {
                        Text("Volume:")
                        Slider(value: $settings.soundVolume, in: 0...1)
                        Text("\(Int(settings.soundVolume * 100))%")
                            .frame(width: 45)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func playSound(_ sound: String) {
        NSSound(named: sound)?.play()
    }
}

struct MeetingLinksView: View {
    @ObservedObject var settings: SettingsManager
    @State private var newLinkName = ""
    @State private var newLinkURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Personal Meeting Links")
                .font(.title2)
                .bold()

            Text("Save your personal meeting room URLs for quick access")
                .font(.caption)
                .foregroundColor(.secondary)

            Form {
                Section(header: Text("Add New Link")) {
                    TextField("Name (e.g., My Zoom Room)", text: $newLinkName)
                    TextField("URL", text: $newLinkURL)

                    Button("Add Link") {
                        if !newLinkName.isEmpty && !newLinkURL.isEmpty {
                            settings.personalMeetingLinks[newLinkName] = newLinkURL
                            newLinkName = ""
                            newLinkURL = ""
                        }
                    }
                    .disabled(newLinkName.isEmpty || newLinkURL.isEmpty)
                }

                Section(header: Text("Saved Links")) {
                    if settings.personalMeetingLinks.isEmpty {
                        Text("No saved links")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(Array(settings.personalMeetingLinks.keys.sorted()), id: \.self) { key in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(key)
                                        .font(.headline)
                                    Text(settings.personalMeetingLinks[key] ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    if let url = URL(string: settings.personalMeetingLinks[key] ?? "") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }) {
                                    Image(systemName: "arrow.up.forward.square")
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button(action: {
                                    settings.personalMeetingLinks.removeValue(forKey: key)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
        .padding()
    }
}

struct CalendarsSettingsView: View {
    @State private var calendars: [EKCalendar] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Connected Calendars")
                .font(.title2)
                .bold()

            Form {
                Section {
                    if calendars.isEmpty {
                        Text("Loading calendars...")
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

                Section(header: Text("Sync Timing")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reveille reads whatever your Mac's Calendar app already has synced — it doesn't sync accounts itself.")
                        Text("• iCloud calendars: typically sync within about a minute")
                        Text("• Google/Outlook calendars: usually sync within a few minutes, depending on how they were added (Internet Accounts vs. a native app)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Section(header: Text("Troubleshooting")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("If a calendar or its events aren't showing up:")
                        Text("1. Open Calendar.app and confirm the calendar is enabled and syncing there first")
                        Text("2. Check System Settings > Privacy & Security > Calendars to confirm Reveille has access")
                        Text("3. If you enabled Reminders alerts, also check the Reminders row in that same Privacy pane")
                        Text("4. Still stuck? Quit and relaunch Reveille — it re-reads calendars fresh on launch")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
        .padding()
        .onAppear {
            loadCalendars()
        }
    }

    private func loadCalendars() {
        let manager = CalendarManager()
        calendars = manager.getCalendars()
    }
}
