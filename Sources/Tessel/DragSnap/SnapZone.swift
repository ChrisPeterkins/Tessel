import CoreGraphics

/// Pure geometric hit-testing: cursor position + screen frame → zone. What
/// each zone *does* is decided by Preferences (zones are remappable). Corners
/// win over edges; a corner is reachable both along the vertical edges (within
/// cornerSize of top/bottom) and along the horizontal edges (within cornerSize
/// of the sides). All in Cocoa coordinates.
enum SnapZone {
    enum Zone: String, CaseIterable {
        case leftEdge, rightEdge, topEdge, bottomEdge
        case topLeftCorner, topRightCorner, bottomLeftCorner, bottomRightCorner

        var title: String {
            switch self {
            case .leftEdge: return "Left Edge"
            case .rightEdge: return "Right Edge"
            case .topEdge: return "Top Edge"
            case .bottomEdge: return "Bottom Edge"
            case .topLeftCorner: return "Top Left Corner"
            case .topRightCorner: return "Top Right Corner"
            case .bottomLeftCorner: return "Bottom Left Corner"
            case .bottomRightCorner: return "Bottom Right Corner"
            }
        }
    }

    struct Config {
        var edgeThreshold: CGFloat = 10
        var cornerSize: CGFloat = 100
    }

    static func zone(at point: CGPoint, screenFrame frame: CGRect, config: Config) -> Zone? {
        let nearLeft = point.x - frame.minX <= config.edgeThreshold
        let nearRight = frame.maxX - point.x <= config.edgeThreshold
        let nearTop = frame.maxY - point.y <= config.edgeThreshold
        let nearBottom = point.y - frame.minY <= config.edgeThreshold

        let withinTopBand = frame.maxY - point.y <= config.cornerSize
        let withinBottomBand = point.y - frame.minY <= config.cornerSize
        let withinLeftBand = point.x - frame.minX <= config.cornerSize
        let withinRightBand = frame.maxX - point.x <= config.cornerSize

        // Corners first.
        if (nearLeft && withinTopBand) || (nearTop && withinLeftBand) { return .topLeftCorner }
        if (nearRight && withinTopBand) || (nearTop && withinRightBand) { return .topRightCorner }
        if (nearLeft && withinBottomBand) || (nearBottom && withinLeftBand) { return .bottomLeftCorner }
        if (nearRight && withinBottomBand) || (nearBottom && withinRightBand) { return .bottomRightCorner }

        // Then edges.
        if nearTop { return .topEdge }
        if nearLeft { return .leftEdge }
        if nearRight { return .rightEdge }
        if nearBottom { return .bottomEdge }

        return nil
    }
}
