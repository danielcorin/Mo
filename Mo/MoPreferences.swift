import AppKit
import Combine
import Foundation

enum AutoHidePolicy: String, CaseIterable, Identifiable {
    case never
    case fiveSeconds
    case tenSeconds
    case thirtySeconds
    case oneMinute
    case appSwitch

    var id: String { rawValue }

    var title: String {
        switch self {
        case .never: "Never"
        case .fiveSeconds: "After 5 seconds"
        case .tenSeconds: "After 10 seconds"
        case .thirtySeconds: "After 30 seconds"
        case .oneMinute: "After 1 minute"
        case .appSwitch: "When the active app changes"
        }
    }

    var delay: TimeInterval? {
        switch self {
        case .never, .appSwitch: nil
        case .fiveSeconds: 5
        case .tenSeconds: 10
        case .thirtySeconds: 30
        case .oneMinute: 60
        }
    }
}

struct Hotkey: Codable, Equatable {
    var keyCode: UInt16
    var modifierFlags: UInt
    var keyName: String

    static let defaultHotkey = Hotkey(
        keyCode: 46,
        modifierFlags: NSEvent.ModifierFlags([.control, .option]).rawValue,
        keyName: "M"
    )

    var displayName: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        return result + keyName
    }

    var isReservedBySystem: Bool {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
            .intersection([.command, .option, .shift, .control])
        return keyCode == 43 && flags == .command
    }

    static func from(event: NSEvent) -> Hotkey? {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        guard !flags.isEmpty else { return nil }
        let hotkey = Hotkey(
            keyCode: event.keyCode,
            modifierFlags: flags.rawValue,
            keyName: keyName(for: event.keyCode)
        )
        return hotkey.isReservedBySystem ? nil : hotkey
    }

    static func keyName(for code: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 49: "Space", 50: "`", 36: "Return",
            48: "Tab", 51: "Delete", 53: "Escape", 123: "←", 124: "→",
            125: "↓", 126: "↑", 122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10",
            103: "F11", 111: "F12",
        ]
        return names[code] ?? "Key \(code)"
    }
}

@MainActor
final class MoPreferences: ObservableObject {
    private enum Key {
        static let autoHidePolicy = "autoHidePolicy"
        static let hideToggle = "hideToggle"
        static let legacyHideToggleWhenHidden = "hideToggleWhenHidden"
        static let hotkey = "hotkey"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let launchAtLoginConfigured = "launchAtLoginConfigured"
    }

    @Published var autoHidePolicy: AutoHidePolicy {
        didSet { defaults.set(autoHidePolicy.rawValue, forKey: Key.autoHidePolicy) }
    }

    @Published var hideToggle: Bool {
        didSet { defaults.set(hideToggle, forKey: Key.hideToggle) }
    }

    @Published var hotkey: Hotkey {
        didSet {
            if let data = try? JSONEncoder().encode(hotkey) {
                defaults.set(data, forKey: Key.hotkey)
            }
        }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: Key.hasCompletedOnboarding)
        }
    }

    var shouldEnableLaunchAtLoginOnFirstRun: Bool {
        !defaults.bool(forKey: Key.launchAtLoginConfigured)
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.autoHidePolicy =
            AutoHidePolicy(
                rawValue: defaults.string(forKey: Key.autoHidePolicy) ?? ""
            ) ?? .tenSeconds
        if defaults.object(forKey: Key.hideToggle) != nil {
            self.hideToggle = defaults.bool(forKey: Key.hideToggle)
        } else {
            self.hideToggle = defaults.bool(forKey: Key.legacyHideToggleWhenHidden)
        }

        if let data = defaults.data(forKey: Key.hotkey),
            let decoded = try? JSONDecoder().decode(Hotkey.self, from: data)
        {
            self.hotkey = decoded
        } else {
            self.hotkey = .defaultHotkey
        }
    }

    func markLaunchAtLoginConfigured() {
        defaults.set(true, forKey: Key.launchAtLoginConfigured)
    }
}
