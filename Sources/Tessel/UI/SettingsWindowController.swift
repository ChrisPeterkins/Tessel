import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(arrangements: ArrangementManager) {
        let hosting = NSHostingController(
            rootView: SettingsView(preferences: Preferences.shared, arrangements: arrangements)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "Tessel Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
