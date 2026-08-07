import AppKit

enum Displays {
    /// Screens in a stable left-to-right (then bottom-to-top) order for
    /// next/previous cycling.
    static var ordered: [NSScreen] {
        NSScreen.screens.sorted {
            if $0.frame.minX != $1.frame.minX { return $0.frame.minX < $1.frame.minX }
            return $0.frame.minY < $1.frame.minY
        }
    }

    /// Screen with the largest overlap with `rect`; falls back to the main screen.
    static func screen(containing rect: CGRect) -> NSScreen? {
        let best = NSScreen.screens.max {
            $0.frame.intersection(rect).area < $1.frame.intersection(rect).area
        }
        if let best, best.frame.intersection(rect).area > 0 { return best }
        return NSScreen.main ?? NSScreen.screens.first
    }

    static func screen(containingPoint point: CGPoint) -> NSScreen? {
        if let hit = NSScreen.screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }) {
            return hit
        }
        return NSScreen.screens.min {
            distance(from: point, to: $0.frame) < distance(from: point, to: $1.frame)
        }
    }

    /// Next (+1) or previous (-1) screen in `ordered`, wrapping around.
    /// Returns nil when there is only one screen.
    static func adjacentScreen(from screen: NSScreen, direction: Int) -> NSScreen? {
        let screens = ordered
        guard screens.count > 1,
              let index = screens.firstIndex(where: { $0.frame == screen.frame }) else { return nil }
        let count = screens.count
        return screens[((index + direction) % count + count) % count]
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }
}
