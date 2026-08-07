import AppKit

/// Orchestrates snap actions: resolves the focused window, computes targets,
/// applies frames, and keeps restore bookkeeping.
final class SnapEngine {
    let frameStore = WindowFrameStore()

    /// When set, snap targets tile within the pin-aware work area instead of
    /// the raw visible frame.
    var pinManager: PinManager?

    private var gap: CGFloat { CGFloat(Preferences.shared.gapSize) }

    func workArea(for screen: NSScreen, pid: pid_t?) -> CGRect {
        pinManager?.workArea(for: screen, requestingPID: pid) ?? screen.visibleFrame
    }

    func perform(_ action: SnapAction) {
        perform(action, on: AXWindow.focused())
    }

    func perform(_ action: SnapAction, on window: AXWindow?) {
        guard let window, !isIgnored(window) else { return }
        let current = window.frame
        guard current.width > 0, current.height > 0,
              let screen = Displays.screen(containing: current) else { return }
        let visible = workArea(for: screen, pid: window.pid)

        switch action {
        case .restore:
            guard let id = window.windowID, let saved = frameStore.savedFrame(for: id) else { return }
            window.setFrame(saved)
            frameStore.didApply(id, frame: saved, action: nil)
        case .nextDisplay:
            moveToAdjacentDisplay(window, current: current, from: screen, direction: 1)
        case .previousDisplay:
            moveToAdjacentDisplay(window, current: current, from: screen, direction: -1)
        case .center, .maximizeHeight, .larger, .smaller, .moveLeft, .moveRight, .moveUp, .moveDown:
            guard let target = relativeTarget(for: action, current: current, visible: visible) else { return }
            snap(window, to: target, within: visible, currentFrame: current, action: action)
        default:
            let cycleIndex = nextCycleIndex(for: action, window: window, current: current)
            guard let target = SnapLayout.target(for: action, on: visible, gap: gap, cycleIndex: cycleIndex) else { return }
            snap(window, to: target, within: visible, currentFrame: current, action: action, cycleIndex: cycleIndex)
        }
    }

    /// Entry point for drag-to-edge snapping. `preDragFrame` is the window's
    /// geometry before the drag started, used as the restore target.
    func snapFromDrag(_ window: AXWindow, action: SnapAction, preDragFrame: CGRect, on screen: NSScreen) {
        let visible = workArea(for: screen, pid: window.pid)
        guard let target = SnapLayout.target(for: action, on: visible, gap: gap) else { return }
        snap(window, to: target, within: visible, currentFrame: preDragFrame, action: action)
    }

    /// Applies a user-defined custom size (fractions of the work area).
    func applyCustomSize(_ size: CustomSize, on window: AXWindow?) {
        guard let window, !isIgnored(window) else { return }
        let current = window.frame
        guard current.width > 0,
              let screen = Displays.screen(containing: current) else { return }
        let visible = workArea(for: screen, pid: window.pid)
        snap(window, to: size.frame(in: visible), within: visible, currentFrame: current, action: nil)
    }

    func isIgnored(_ window: AXWindow) -> Bool {
        guard let bundleID = NSRunningApplication(processIdentifier: window.pid)?.bundleIdentifier else { return false }
        return Preferences.shared.ignoredBundleIDs.contains(bundleID)
    }

    // MARK: - Private

    /// Repeated presses of a half action while the window is still where we
    /// left it cycle the size ½ → ⅔ → ⅓.
    private func nextCycleIndex(for action: SnapAction, window: AXWindow, current: CGRect) -> Int {
        guard Preferences.shared.cycleHalves,
              SnapLayout.cyclableActions.contains(action),
              let id = window.windowID,
              frameStore.lastAction(for: id) == action,
              let applied = frameStore.lastAppliedFrame(for: id),
              applied.approximatelyEquals(current) else { return 0 }
        return (frameStore.cycleIndex(for: id) + 1) % SnapLayout.halfCycleFractions.count
    }

    /// Targets that depend on the window's current frame.
    private func relativeTarget(for action: SnapAction, current: CGRect, visible: CGRect) -> CGRect? {
        switch action {
        case .center:
            return CGRect(
                x: (visible.midX - current.width / 2).rounded(),
                y: (visible.midY - current.height / 2).rounded(),
                width: current.width,
                height: current.height
            )
        case .maximizeHeight:
            return CGRect(
                x: current.minX,
                y: visible.minY + gap,
                width: current.width,
                height: visible.height - 2 * gap
            )
        case .larger, .smaller:
            let delta: CGFloat = action == .larger ? 30 : -30
            // Never grow a window that's already tiny just because of the floor.
            let minW = min(current.width, 100)
            let minH = min(current.height, 100)
            let width = min(max(current.width + delta, minW), visible.width)
            let height = min(max(current.height + delta, minH), visible.height)
            var target = CGRect(
                x: (current.midX - width / 2).rounded(),
                y: (current.midY - height / 2).rounded(),
                width: width,
                height: height
            )
            target.origin = clampOrigin(target.origin, size: target.size, within: visible)
            return target
        case .moveLeft:
            return current.with(x: visible.minX + gap)
        case .moveRight:
            return current.with(x: visible.maxX - gap - current.width)
        case .moveUp:
            return current.with(y: visible.maxY - gap - current.height)
        case .moveDown:
            return current.with(y: visible.minY + gap)
        default:
            return nil
        }
    }

    private func snap(_ window: AXWindow, to target: CGRect, within visible: CGRect, currentFrame: CGRect, action: SnapAction?, cycleIndex: Int = 0) {
        if let id = window.windowID {
            frameStore.recordIfNeeded(id, currentFrame: currentFrame)
        }

        let achieved: CGRect
        if window.isResizable {
            window.setFrame(target)
            achieved = reconcile(window, target: target, visible: visible)
        } else {
            // Can't resize: center the window inside the target zone instead.
            let size = currentFrame.size
            let origin = CGPoint(x: target.midX - size.width / 2, y: target.midY - size.height / 2)
            window.move(toCocoaOrigin: clampOrigin(origin, size: size, within: visible), size: size)
            achieved = window.frame
        }

        if let id = window.windowID {
            frameStore.didApply(id, frame: achieved, action: action, cycleIndex: cycleIndex)
        }
    }

    /// Apps with a minimum size can refuse the target size. Read back what was
    /// achieved and pin the window to the zone's natural edge (e.g. right-align
    /// for right half) so it at least hugs the correct side of the screen.
    private func reconcile(_ window: AXWindow, target: CGRect, visible: CGRect) -> CGRect {
        var achieved = window.frame
        let oversizedX = achieved.width > target.width + 1.5
        let oversizedY = achieved.height > target.height + 1.5
        guard oversizedX || oversizedY else { return achieved }

        var origin = target.origin
        let touchesRightOnly = abs(target.maxX - visible.maxX) < 1.5 && target.minX - visible.minX > 1.5
        let touchesTopOnly = abs(target.maxY - visible.maxY) < 1.5 && target.minY - visible.minY > 1.5
        if oversizedX, touchesRightOnly { origin.x = target.maxX - achieved.width }
        if oversizedY, touchesTopOnly { origin.y = target.maxY - achieved.height }

        window.move(toCocoaOrigin: clampOrigin(origin, size: achieved.size, within: visible), size: achieved.size)
        achieved = window.frame
        return achieved
    }

    private func clampOrigin(_ origin: CGPoint, size: CGSize, within visible: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - size.width)),
            y: min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - size.height))
        )
    }

    private func moveToAdjacentDisplay(_ window: AXWindow, current: CGRect, from screen: NSScreen, direction: Int) {
        guard let destination = Displays.adjacentScreen(from: screen, direction: direction) else { return }
        let source = workArea(for: screen, pid: window.pid)
        let dest = workArea(for: destination, pid: window.pid)

        // If the window sits exactly where we last snapped it, re-apply the
        // same snap on the destination screen instead of scaling geometry.
        if let id = window.windowID,
           let action = frameStore.lastAction(for: id),
           let applied = frameStore.lastAppliedFrame(for: id),
           applied.approximatelyEquals(current),
           let target = SnapLayout.target(for: action, on: dest, gap: gap, cycleIndex: frameStore.cycleIndex(for: id)) {
            snap(window, to: target, within: dest, currentFrame: current, action: action, cycleIndex: frameStore.cycleIndex(for: id))
            return
        }

        // Otherwise preserve the window's geometry relative to the screen's
        // visible area (handles different resolutions/scale factors).
        let fx = (current.minX - source.minX) / source.width
        let fy = (current.minY - source.minY) / source.height
        let fw = min(current.width / source.width, 1)
        let fh = min(current.height / source.height, 1)
        let target = CGRect(
            x: dest.minX + fx * dest.width,
            y: dest.minY + fy * dest.height,
            width: fw * dest.width,
            height: fh * dest.height
        ).integral
        snap(window, to: target, within: dest, currentFrame: current, action: nil)
    }
}

private extension CGRect {
    func with(x: CGFloat? = nil, y: CGFloat? = nil) -> CGRect {
        CGRect(x: x ?? minX, y: y ?? minY, width: width, height: height)
    }
}
