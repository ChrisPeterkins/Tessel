import AppKit

/// Remembers, per window, the last frame the *user* gave it (for Restore), the
/// last frame *we* applied (to tell "still where we snapped it" apart from
/// "user moved it since"), and the half-cycle position for repeated presses.
final class WindowFrameStore {
    private struct Entry {
        var userFrame: CGRect
        var lastAppliedFrame: CGRect?
        var lastAction: SnapAction?
        var cycleIndex: Int = 0
    }

    private var entries: [CGWindowID: Entry] = [:]

    /// Call before applying a snap, with the window's current frame. Saves it
    /// as the restore target unless the window is still exactly where a
    /// previous snap left it (so left half → right half → restore returns the
    /// original hand-placed frame).
    func recordIfNeeded(_ id: CGWindowID, currentFrame: CGRect) {
        pruneIfNeeded()
        if let entry = entries[id],
           let applied = entry.lastAppliedFrame,
           applied.approximatelyEquals(currentFrame) {
            return
        }
        var entry = entries[id] ?? Entry(userFrame: currentFrame)
        entry.userFrame = currentFrame
        entries[id] = entry
    }

    func didApply(_ id: CGWindowID, frame: CGRect, action: SnapAction?, cycleIndex: Int = 0) {
        var entry = entries[id] ?? Entry(userFrame: frame)
        entry.lastAppliedFrame = frame
        entry.lastAction = action
        entry.cycleIndex = cycleIndex
        entries[id] = entry
    }

    func savedFrame(for id: CGWindowID) -> CGRect? { entries[id]?.userFrame }
    func lastAppliedFrame(for id: CGWindowID) -> CGRect? { entries[id]?.lastAppliedFrame }
    func lastAction(for id: CGWindowID) -> SnapAction? { entries[id]?.lastAction }
    func cycleIndex(for id: CGWindowID) -> Int { entries[id]?.cycleIndex ?? 0 }

    private func pruneIfNeeded() {
        guard entries.count > 40 else { return }
        guard let info = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        let alive = Set(info.compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value })
        entries = entries.filter { alive.contains($0.key) }
    }
}
