import AppKit

/// App pinning: reserves a strip on one side of the screen for a chosen app
/// (like Rectangle's Todo mode). The pinned app's front window is kept in the
/// strip, and every other snap target tiles within the remaining work area.
final class PinManager {
    private let preferences = Preferences.shared

    var isActive: Bool { !(preferences.pinnedBundleID ?? "").isEmpty }

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(displaysChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func pinnedApp() -> NSRunningApplication? {
        guard let bundleID = preferences.pinnedBundleID, !bundleID.isEmpty else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

    func pinnedWindow() -> AXWindow? {
        guard let app = pinnedApp() else { return nil }
        return AXWindow.windows(ofPID: app.processIdentifier).first { $0.isManageable && !$0.isMinimized }
    }

    /// The screen area available to non-pinned windows. The pinned app itself
    /// (matched by pid) gets the full visible frame.
    func workArea(for screen: NSScreen, requestingPID: pid_t?) -> CGRect {
        let visible = screen.visibleFrame
        guard isActive else { return visible }
        if let pid = requestingPID, pid == pinnedApp()?.processIdentifier { return visible }
        guard let pinned = pinnedWindow(),
              let pinnedScreen = Displays.screen(containing: pinned.frame),
              pinnedScreen.frame == screen.frame else { return visible }

        let stripWidth = (visible.width * CGFloat(preferences.pinnedWidthFraction)).rounded(.down)
        if preferences.pinnedSide == "left" {
            return CGRect(x: visible.minX + stripWidth, y: visible.minY, width: visible.width - stripWidth, height: visible.height)
        }
        return CGRect(x: visible.minX, y: visible.minY, width: visible.width - stripWidth, height: visible.height)
    }

    /// Moves the pinned app's front window into its reserved strip.
    func applyPin() {
        guard let pinned = pinnedWindow() else { return }
        let screen = Displays.screen(containing: pinned.frame) ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        let stripWidth = (visible.width * CGFloat(preferences.pinnedWidthFraction)).rounded(.down)
        let strip: CGRect
        if preferences.pinnedSide == "left" {
            strip = CGRect(x: visible.minX, y: visible.minY, width: stripWidth, height: visible.height)
        } else {
            strip = CGRect(x: visible.maxX - stripWidth, y: visible.minY, width: stripWidth, height: visible.height)
        }
        pinned.setFrame(strip)
    }

    func pinFrontmost() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              bundleID != Bundle.main.bundleIdentifier else { return }
        preferences.pinnedBundleID = bundleID
        applyPin()
    }

    func unpin() {
        preferences.pinnedBundleID = nil
    }

    @objc private func appActivated(_ note: Notification) {
        guard isActive,
              let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == preferences.pinnedBundleID else { return }
        // Re-dock the pinned window when its app comes forward (it may have
        // been moved while in the background).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.applyPin()
        }
    }

    @objc private func displaysChanged() {
        guard isActive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.applyPin()
        }
    }
}
