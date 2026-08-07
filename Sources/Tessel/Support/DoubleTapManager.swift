import AppKit
import QuartzCore

/// Detects a double-tap of a lone modifier key (e.g. ⌥⌥) via global event
/// monitors and fires the configured action. A "tap" is press+release of the
/// modifier with no other key or modifier involved.
final class DoubleTapManager {
    var onTrigger: (() -> Void)?

    private var flagsMonitor: Any?
    private var keyMonitor: Any?
    private var pressedAlone = false
    private var lastTapTime: CFTimeInterval = 0
    private static let interval: CFTimeInterval = 0.35

    private var targetFlags: NSEvent.ModifierFlags? {
        switch Preferences.shared.doubleTapModifier {
        case "control": return .control
        case "option": return .option
        case "command": return .command
        case "shift": return .shift
        default: return nil
        }
    }

    /// (Re)installs monitors according to the current preference. Requires
    /// Accessibility trust (global monitors are inert without it).
    func reconfigure() {
        stop()
        guard targetFlags != nil else { return }

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            // Any real keystroke invalidates the tap sequence (it was a chord).
            self?.pressedAlone = false
            self?.lastTapTime = 0
        }
    }

    func stop() {
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        flagsMonitor = nil
        keyMonitor = nil
        pressedAlone = false
        lastTapTime = 0
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard let target = targetFlags else { return }
        let active = event.modifierFlags.intersection([.control, .option, .command, .shift])
        if active == target {
            pressedAlone = true
        } else if active.isEmpty {
            if pressedAlone {
                let now = CACurrentMediaTime()
                if now - lastTapTime < Self.interval {
                    lastTapTime = 0
                    onTrigger?()
                } else {
                    lastTapTime = now
                }
            }
            pressedAlone = false
        } else {
            // A different/extra modifier joined: not a lone tap.
            pressedAlone = false
            lastTapTime = 0
        }
    }
}
