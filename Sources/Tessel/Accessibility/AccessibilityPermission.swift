import AppKit
import ApplicationServices

enum AccessibilityPermission {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Prompts for Accessibility permission if needed, then invokes `onGranted`
    /// (immediately when already trusted). TCC does not notify the process when
    /// the user flips the checkbox, so we poll.
    static func ensureTrusted(onGranted: @escaping () -> Void) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            onGranted()
            return
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                onGranted()
            }
        }
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
