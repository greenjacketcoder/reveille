import AppKit
import Carbon.HIToolbox

/// Registers a system-wide hotkey via Carbon's `RegisterEventHotKey`.
///
/// Why Carbon rather than the alternatives:
/// - A global `NSEvent` monitor (`addGlobalMonitorForEvents`) requires the
///   Accessibility permission — that would mean asking users to let Reveille
///   observe all keyboard input system-wide, which is wildly disproportionate
///   for one shortcut and at odds with the app's minimal-access stance.
/// - A third-party shortcut package would add a remote dependency to a project
///   that deliberately minimises and pins them.
/// `RegisterEventHotKey` needs no extra permission, works inside the sandbox,
/// and is a stable, long-documented API.
final class HotKeyManager {

    /// Carbon modifier mask helpers (Carbon uses its own bit values, not
    /// NSEvent.ModifierFlags).
    struct Modifiers {
        static let command = UInt32(cmdKey)
        static let option = UInt32(optionKey)
        static let control = UInt32(controlKey)
        static let shift = UInt32(shiftKey)
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var action: (() -> Void)?

    /// Live managers keyed by hotkey id. The Carbon callback is a C function
    /// pointer, so it cannot capture `self` — it looks the instance up here.
    private static var registry: [UInt32: HotKeyManager] = [:]
    private static var nextID: UInt32 = 1

    private let id: UInt32

    init() {
        self.id = HotKeyManager.nextID
        HotKeyManager.nextID += 1
    }

    deinit {
        unregister()
    }

    var isRegistered: Bool { hotKeyRef != nil }

    /// Registers the hotkey. Returns false if the system refused it — most
    /// often because another app already owns that combination, which the
    /// caller should surface rather than fail silently.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        unregister()
        self.action = action
        HotKeyManager.registry[id] = self

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                HotKeyManager.registry[hotKeyID.id]?.action?()
                return noErr
            },
            1,
            &spec,
            nil,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            HotKeyManager.registry[id] = nil
            self.action = nil
            return false
        }

        // 'RVLL' — a signature unique to this app's hotkeys.
        let hotKeyID = EventHotKeyID(signature: OSType(0x5256_4C4C), id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status != noErr {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        HotKeyManager.registry[id] = nil
        action = nil
    }
}

/// The shortcut choices offered in Preferences. A small preset list rather than
/// a free-form recorder: these ⌃⌥⌘ combinations are very unlikely to collide
/// with system or app shortcuts, and it avoids shipping a half-built recorder
/// UI. A full recorder can come later without changing the stored format.
struct JoinShortcut: Identifiable, Equatable {
    let id: String
    let label: String
    let keyCode: UInt32
    let modifiers: UInt32

    static let all: [JoinShortcut] = [
        JoinShortcut(id: "ctrl-opt-cmd-j", label: "⌃⌥⌘J", keyCode: UInt32(kVK_ANSI_J),
                     modifiers: Modifiers.combo),
        JoinShortcut(id: "ctrl-opt-cmd-m", label: "⌃⌥⌘M", keyCode: UInt32(kVK_ANSI_M),
                     modifiers: Modifiers.combo),
        JoinShortcut(id: "ctrl-opt-cmd-k", label: "⌃⌥⌘K", keyCode: UInt32(kVK_ANSI_K),
                     modifiers: Modifiers.combo),
        JoinShortcut(id: "ctrl-opt-cmd-return", label: "⌃⌥⌘↩", keyCode: UInt32(kVK_Return),
                     modifiers: Modifiers.combo),
    ]

    static var `default`: JoinShortcut { all[0] }

    static func named(_ id: String) -> JoinShortcut {
        all.first { $0.id == id } ?? .default
    }

    private enum Modifiers {
        static let combo = HotKeyManager.Modifiers.control
            | HotKeyManager.Modifiers.option
            | HotKeyManager.Modifiers.command
    }
}
