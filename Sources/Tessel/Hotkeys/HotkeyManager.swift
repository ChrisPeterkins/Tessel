import AppKit
import Carbon.HIToolbox

/// Registers global hotkeys via Carbon RegisterEventHotKey — the keystrokes are
/// consumed system-wide (the frontmost app never sees them) and no special
/// permission is required.
final class HotkeyManager {
    var onAction: ((SnapAction) -> Void)?
    /// ⌃⌥1–9 apply workspace arrangements; ⌃⌥⇧1–9 apply custom sizes.
    var onArrangement: ((Int) -> Void)?
    var onCustomSize: ((Int) -> Void)?
    var arrangementCount: () -> Int = { 0 }
    var customSizeCount: () -> Int = { 0 }

    private var handlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var actionsByID: [UInt32: SnapAction] = [:]
    private static let signature: OSType = 0x5453_534C // 'TSSL'
    private static let arrangementIDBase: UInt32 = 1000
    private static let customSizeIDBase: UInt32 = 2000
    /// Key codes for the digit keys 1–9 (not contiguous on ANSI layouts).
    private static let digitKeyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

    func start() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
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
            if status == noErr {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkey(id: hotKeyID.id)
            }
            return noErr
        }, 1, &eventType, selfPtr, &handlerRef)

        let bindings = Keycodes.effectiveBindings(customShortcuts: Preferences.shared.customShortcuts)
        for (index, binding) in bindings.enumerated() {
            let id = UInt32(index + 1)
            actionsByID[id] = binding.action
            register(keyCode: binding.keyCode, modifiers: binding.modifiers, id: id, label: "\(binding.action)")
        }

        // Indexed hotkeys, registered only for slots that exist so unused
        // digit combos stay available to other apps.
        for index in 0..<min(arrangementCount(), 9) {
            register(
                keyCode: Self.digitKeyCodes[index],
                modifiers: Keycodes.baseModifiers,
                id: Self.arrangementIDBase + UInt32(index),
                label: "arrangement \(index + 1)"
            )
        }
        for index in 0..<min(customSizeCount(), 9) {
            register(
                keyCode: Self.digitKeyCodes[index],
                modifiers: Keycodes.shiftBaseModifiers,
                id: Self.customSizeIDBase + UInt32(index),
                label: "custom size \(index + 1)"
            )
        }
    }

    private func register(keyCode: UInt32, modifiers: UInt32, id: UInt32, label: String) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
        if status == noErr, let ref {
            hotKeyRefs.append(ref)
        } else {
            NSLog("Tessel: failed to register hotkey for \(label) (status \(status))")
        }
    }

    /// Re-registers everything from the current effective bindings.
    func reload() {
        guard handlerRef != nil else { return } // not started yet
        stop()
        start()
    }

    func stop() {
        hotKeyRefs.forEach { UnregisterEventHotKey($0) }
        hotKeyRefs.removeAll()
        actionsByID.removeAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }

    private func handleHotkey(id: UInt32) {
        if id >= Self.customSizeIDBase {
            onCustomSize?(Int(id - Self.customSizeIDBase))
        } else if id >= Self.arrangementIDBase {
            onArrangement?(Int(id - Self.arrangementIDBase))
        } else if let action = actionsByID[id] {
            onAction?(action)
        }
    }
}
