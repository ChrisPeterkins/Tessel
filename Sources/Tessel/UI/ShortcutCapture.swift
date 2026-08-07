import AppKit
import Carbon.HIToolbox
import Combine

/// Captures the next keystroke (with modifiers) while recording a custom
/// shortcut in the settings window. Escape cancels; combos without at least
/// one of ⌃⌥⌘ are rejected (they'd shadow normal typing system-wide).
final class ShortcutCapture: ObservableObject {
    @Published var recordingAction: SnapAction?

    private var monitor: Any?

    func begin(for action: SnapAction, onCapture: @escaping (_ keyCode: Int, _ carbonModifiers: Int) -> Void) {
        cancel()
        recordingAction = action
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == UInt16(kVK_Escape) {
                self.cancel()
                return nil
            }
            let mods = Keycodes.carbonModifiers(from: event.modifierFlags)
            let strongModifiers = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)
            guard mods & strongModifiers != 0 else {
                NSSound.beep()
                return nil
            }
            onCapture(Int(event.keyCode), Int(mods))
            self.cancel()
            return nil
        }
    }

    func cancel() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        recordingAction = nil
    }
}
