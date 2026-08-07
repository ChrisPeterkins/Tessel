import AppKit

/// The Accessibility API uses a global TOP-left-origin coordinate space; Cocoa
/// (NSScreen, NSWindow) uses a BOTTOM-left origin, both anchored on the primary
/// screen. Conversion flips Y around the primary screen's top edge. All internal
/// logic works in Cocoa coordinates; AX coordinates exist only at the AX boundary
/// (AXWindow) and at CGEvent locations.
enum Coordinates {
    /// Height of the primary screen (`NSScreen.screens[0]`, always at Cocoa origin).
    static var primaryScreenMaxY: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    static func axFrame(fromCocoa rect: CGRect, primaryMaxY: CGFloat? = nil) -> CGRect {
        let maxY = primaryMaxY ?? primaryScreenMaxY
        return CGRect(x: rect.minX, y: maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    static func cocoaFrame(fromAX rect: CGRect, primaryMaxY: CGFloat? = nil) -> CGRect {
        let maxY = primaryMaxY ?? primaryScreenMaxY
        return CGRect(x: rect.minX, y: maxY - rect.minY - rect.height, width: rect.width, height: rect.height)
    }

    static func axPoint(fromCocoa point: CGPoint, primaryMaxY: CGFloat? = nil) -> CGPoint {
        let maxY = primaryMaxY ?? primaryScreenMaxY
        return CGPoint(x: point.x, y: maxY - point.y)
    }

    static func cocoaPoint(fromAX point: CGPoint, primaryMaxY: CGFloat? = nil) -> CGPoint {
        let maxY = primaryMaxY ?? primaryScreenMaxY
        return CGPoint(x: point.x, y: maxY - point.y)
    }
}
