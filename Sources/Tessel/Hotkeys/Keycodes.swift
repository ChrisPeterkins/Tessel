import AppKit
import Carbon.HIToolbox

/// Default hotkey map plus the machinery for user overrides. The effective
/// bindings are the defaults with Preferences.customShortcuts layered on top
/// (keyCode -1 = explicitly unassigned).
enum Keycodes {
    struct Binding {
        let action: SnapAction
        let keyCode: UInt32
        let modifiers: UInt32
    }

    static let baseModifiers = UInt32(controlKey | optionKey)
    static let shiftBaseModifiers = UInt32(controlKey | optionKey | shiftKey)
    static let displayModifiers = UInt32(controlKey | optionKey | cmdKey)

    static let defaultBindings: [Binding] = [
        Binding(action: .leftHalf, keyCode: UInt32(kVK_LeftArrow), modifiers: baseModifiers),
        Binding(action: .rightHalf, keyCode: UInt32(kVK_RightArrow), modifiers: baseModifiers),
        Binding(action: .topHalf, keyCode: UInt32(kVK_UpArrow), modifiers: baseModifiers),
        Binding(action: .bottomHalf, keyCode: UInt32(kVK_DownArrow), modifiers: baseModifiers),
        Binding(action: .topLeftQuarter, keyCode: UInt32(kVK_ANSI_U), modifiers: baseModifiers),
        Binding(action: .topRightQuarter, keyCode: UInt32(kVK_ANSI_I), modifiers: baseModifiers),
        Binding(action: .bottomLeftQuarter, keyCode: UInt32(kVK_ANSI_J), modifiers: baseModifiers),
        Binding(action: .bottomRightQuarter, keyCode: UInt32(kVK_ANSI_K), modifiers: baseModifiers),
        Binding(action: .leftThird, keyCode: UInt32(kVK_ANSI_D), modifiers: baseModifiers),
        Binding(action: .centerThird, keyCode: UInt32(kVK_ANSI_F), modifiers: baseModifiers),
        Binding(action: .rightThird, keyCode: UInt32(kVK_ANSI_G), modifiers: baseModifiers),
        Binding(action: .firstTwoThirds, keyCode: UInt32(kVK_ANSI_E), modifiers: baseModifiers),
        Binding(action: .lastTwoThirds, keyCode: UInt32(kVK_ANSI_T), modifiers: baseModifiers),
        Binding(action: .maximize, keyCode: UInt32(kVK_Return), modifiers: baseModifiers),
        Binding(action: .almostMaximize, keyCode: UInt32(kVK_ANSI_A), modifiers: baseModifiers),
        Binding(action: .maximizeHeight, keyCode: UInt32(kVK_UpArrow), modifiers: shiftBaseModifiers),
        Binding(action: .center, keyCode: UInt32(kVK_ANSI_C), modifiers: baseModifiers),
        Binding(action: .larger, keyCode: UInt32(kVK_ANSI_Equal), modifiers: baseModifiers),
        Binding(action: .smaller, keyCode: UInt32(kVK_ANSI_Minus), modifiers: baseModifiers),
        Binding(action: .restore, keyCode: UInt32(kVK_Delete), modifiers: baseModifiers),
        Binding(action: .nextDisplay, keyCode: UInt32(kVK_RightArrow), modifiers: displayModifiers),
        Binding(action: .previousDisplay, keyCode: UInt32(kVK_LeftArrow), modifiers: displayModifiers),
        Binding(action: .showThrowPanel, keyCode: UInt32(kVK_Space), modifiers: baseModifiers),
        Binding(action: .stashLeft, keyCode: UInt32(kVK_LeftArrow), modifiers: shiftBaseModifiers),
        Binding(action: .stashRight, keyCode: UInt32(kVK_RightArrow), modifiers: shiftBaseModifiers),
        Binding(action: .unstashAll, keyCode: UInt32(kVK_Delete), modifiers: shiftBaseModifiers),
        // Fourths, sixths, and move-to-edge ship unassigned (menu + custom
        // shortcuts); there aren't enough comfortable default combos left.
    ]

    /// Defaults with user overrides applied.
    static func effectiveBindings(customShortcuts: [String: [String: Int]]) -> [Binding] {
        var result: [Binding] = []
        for action in SnapAction.allCases {
            if let custom = customShortcuts[action.rawValue] {
                if let code = custom["keyCode"], code >= 0, let mods = custom["modifiers"] {
                    result.append(Binding(action: action, keyCode: UInt32(code), modifiers: UInt32(mods)))
                }
                // code < 0: explicitly unassigned — suppress any default.
            } else if let def = defaultBindings.first(where: { $0.action == action }) {
                result.append(def)
            }
        }
        return result
    }

    static func binding(for action: SnapAction, customShortcuts: [String: [String: Int]]) -> Binding? {
        effectiveBindings(customShortcuts: customShortcuts).first { $0.action == action }
    }

    // MARK: - Display

    static let keyLabels: [UInt32: String] = {
        var labels: [UInt32: String] = [
            UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
            UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
            UInt32(kVK_Return): "↩", UInt32(kVK_Delete): "⌫",
            UInt32(kVK_ForwardDelete): "⌦", UInt32(kVK_Escape): "⎋",
            UInt32(kVK_Tab): "⇥", UInt32(kVK_Space): "Space",
            UInt32(kVK_Home): "↖", UInt32(kVK_End): "↘",
            UInt32(kVK_PageUp): "⇞", UInt32(kVK_PageDown): "⇟",
            UInt32(kVK_ANSI_Equal): "=", UInt32(kVK_ANSI_Minus): "-",
            UInt32(kVK_ANSI_LeftBracket): "[", UInt32(kVK_ANSI_RightBracket): "]",
            UInt32(kVK_ANSI_Semicolon): ";", UInt32(kVK_ANSI_Quote): "'",
            UInt32(kVK_ANSI_Comma): ",", UInt32(kVK_ANSI_Period): ".",
            UInt32(kVK_ANSI_Slash): "/", UInt32(kVK_ANSI_Backslash): "\\",
            UInt32(kVK_ANSI_Grave): "`",
        ]
        let letters: [(Int, String)] = [
            (kVK_ANSI_A, "A"), (kVK_ANSI_B, "B"), (kVK_ANSI_C, "C"), (kVK_ANSI_D, "D"),
            (kVK_ANSI_E, "E"), (kVK_ANSI_F, "F"), (kVK_ANSI_G, "G"), (kVK_ANSI_H, "H"),
            (kVK_ANSI_I, "I"), (kVK_ANSI_J, "J"), (kVK_ANSI_K, "K"), (kVK_ANSI_L, "L"),
            (kVK_ANSI_M, "M"), (kVK_ANSI_N, "N"), (kVK_ANSI_O, "O"), (kVK_ANSI_P, "P"),
            (kVK_ANSI_Q, "Q"), (kVK_ANSI_R, "R"), (kVK_ANSI_S, "S"), (kVK_ANSI_T, "T"),
            (kVK_ANSI_U, "U"), (kVK_ANSI_V, "V"), (kVK_ANSI_W, "W"), (kVK_ANSI_X, "X"),
            (kVK_ANSI_Y, "Y"), (kVK_ANSI_Z, "Z"),
            (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"), (kVK_ANSI_3, "3"),
            (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"), (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"),
            (kVK_ANSI_8, "8"), (kVK_ANSI_9, "9"),
        ]
        for (code, label) in letters { labels[UInt32(code)] = label }
        return labels
    }()

    static func keyLabel(for keyCode: UInt32) -> String {
        keyLabels[keyCode] ?? "key\(keyCode)"
    }

    static func displayString(for binding: Binding) -> String {
        var mods = ""
        if binding.modifiers & UInt32(controlKey) != 0 { mods += "⌃" }
        if binding.modifiers & UInt32(optionKey) != 0 { mods += "⌥" }
        if binding.modifiers & UInt32(shiftKey) != 0 { mods += "⇧" }
        if binding.modifiers & UInt32(cmdKey) != 0 { mods += "⌘" }
        return mods + keyLabel(for: binding.keyCode)
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        return mods
    }
}
