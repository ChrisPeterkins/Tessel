import AppKit

/// Hides windows off the left/right screen edge leaving a small sliver; they
/// slide back out when the cursor touches the sliver and re-stash when the
/// cursor leaves. Cursor tracking is a cheap 10 Hz poll that only runs while
/// something is stashed.
final class StashManager {
    enum Edge { case left, right }

    private struct Stashed {
        let window: AXWindow
        let edge: Edge
        let restoreFrame: CGRect
        var stashFrame: CGRect
        var revealFrame: CGRect
        var revealed = false
    }

    private static let sliver: CGFloat = 12

    private var stashed: [CGWindowID: Stashed] = [:]
    private var pollTimer: Timer?

    /// Stashes the window; if it's already stashed, unstashes it instead.
    func toggleStash(_ window: AXWindow?, edge: Edge) {
        guard let window, let id = window.windowID else { return }
        if stashed[id] != nil {
            unstash(id)
            return
        }
        let frame = window.frame
        guard frame.width > 0, let screen = Displays.screen(containing: frame) else { return }
        let full = screen.frame

        var stashFrame = frame
        var revealFrame = frame
        switch edge {
        case .left:
            stashFrame.origin.x = full.minX - frame.width + Self.sliver
            revealFrame.origin.x = full.minX
        case .right:
            stashFrame.origin.x = full.maxX - Self.sliver
            revealFrame.origin.x = full.maxX - frame.width
        }

        window.move(toCocoaOrigin: stashFrame.origin, size: frame.size)
        stashed[id] = Stashed(
            window: window,
            edge: edge,
            restoreFrame: frame,
            stashFrame: stashFrame,
            revealFrame: revealFrame
        )
        startPollingIfNeeded()
    }

    func unstash(_ id: CGWindowID) {
        guard let entry = stashed.removeValue(forKey: id) else { return }
        entry.window.move(toCocoaOrigin: entry.restoreFrame.origin, size: entry.restoreFrame.size)
        stopPollingIfIdle()
    }

    func unstashAll() {
        for id in Array(stashed.keys) {
            unstash(id)
        }
    }

    // MARK: - Cursor polling

    private func startPollingIfNeeded() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func stopPollingIfIdle() {
        guard stashed.isEmpty else { return }
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func tick() {
        let mouse = NSEvent.mouseLocation
        for (id, entry) in stashed {
            let current = entry.window.frame
            guard current.width > 0 else {
                stashed.removeValue(forKey: id) // window closed
                continue
            }

            if !entry.revealed {
                // The visible sliver, generously padded for easier targeting.
                let trigger = CGRect(
                    x: entry.edge == .left ? entry.stashFrame.minX : entry.stashFrame.maxX - Self.sliver - 4,
                    y: entry.stashFrame.minY,
                    width: Self.sliver + 4,
                    height: entry.stashFrame.height
                )
                if trigger.contains(mouse) {
                    entry.window.move(toCocoaOrigin: entry.revealFrame.origin, size: entry.revealFrame.size)
                    entry.window.raise()
                    NSRunningApplication(processIdentifier: entry.window.pid)?.activate()
                    stashed[id]?.revealed = true
                }
            } else {
                // If the user dragged the revealed window away, hand it back.
                if !current.approximatelyEquals(entry.revealFrame, tolerance: 50) {
                    stashed.removeValue(forKey: id)
                    continue
                }
                // Cursor left the window: slide it back into the edge.
                if !current.insetBy(dx: -10, dy: -10).contains(mouse) {
                    entry.window.move(toCocoaOrigin: entry.stashFrame.origin, size: entry.stashFrame.size)
                    stashed[id]?.revealed = false
                }
            }
        }
        stopPollingIfIdle()
    }
}
