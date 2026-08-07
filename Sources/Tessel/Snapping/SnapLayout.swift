import CoreGraphics

/// Pure layout math: action + a screen's visible frame (Cocoa coords, already
/// excluding menu bar and Dock) → target window frame. Fractional widths are
/// floored and the remainder given to the last piece so tiles cover the screen
/// exactly with no gaps or overlap.
enum SnapLayout {
    /// Sizes cycled by repeated presses of a half action: ½ → ⅔ → ⅓.
    static let halfCycleFractions: [CGFloat] = [1.0 / 2.0, 2.0 / 3.0, 1.0 / 3.0]

    static let cyclableActions: Set<SnapAction> = [.leftHalf, .rightHalf, .topHalf, .bottomHalf]

    /// Returns nil for actions whose target depends on the window's current
    /// frame (center, maximizeHeight, larger/smaller, moves) or that aren't
    /// frame-based at all (restore, next/previousDisplay). `gap` adds padding
    /// between windows and screen edges; `cycleIndex` selects the half-cycle
    /// fraction for half actions.
    static func target(for action: SnapAction, on visible: CGRect, gap: CGFloat = 0, cycleIndex: Int = 0) -> CGRect? {
        guard let base = baseTarget(for: action, on: visible, cycleIndex: cycleIndex) else { return nil }
        guard gap > 0, action != .almostMaximize else { return base }
        return applyGap(base, visible: visible, gap: gap)
    }

    /// Insets a tile: sides on a screen edge get the full gap, interior sides
    /// get half (two adjacent tiles then leave exactly one gap between them).
    static func applyGap(_ rect: CGRect, visible: CGRect, gap: CGFloat) -> CGRect {
        let tolerance: CGFloat = 0.5
        let left = abs(rect.minX - visible.minX) <= tolerance ? gap : gap / 2
        let right = abs(rect.maxX - visible.maxX) <= tolerance ? gap : gap / 2
        let bottom = abs(rect.minY - visible.minY) <= tolerance ? gap : gap / 2
        let top = abs(rect.maxY - visible.maxY) <= tolerance ? gap : gap / 2
        return CGRect(
            x: rect.minX + left,
            y: rect.minY + bottom,
            width: rect.width - left - right,
            height: rect.height - bottom - top
        )
    }

    // MARK: - Private

    private static func baseTarget(for action: SnapAction, on v: CGRect, cycleIndex: Int) -> CGRect? {
        let index = ((cycleIndex % 3) + 3) % 3
        let fraction = halfCycleFractions[index]
        let halfW = (v.width / 2).rounded(.down)
        let halfH = (v.height / 2).rounded(.down)
        let thirdW = (v.width / 3).rounded(.down)
        let fourthW = (v.width / 4).rounded(.down)

        switch action {
        // Halves: cycle index 0 keeps the exact-tiling split; other indices
        // anchor a ⅔/⅓-sized window at the action's edge.
        case .leftHalf:
            let w = index == 0 ? halfW : (v.width * fraction).rounded(.down)
            return CGRect(x: v.minX, y: v.minY, width: w, height: v.height)
        case .rightHalf:
            if index == 0 {
                return CGRect(x: v.minX + halfW, y: v.minY, width: v.width - halfW, height: v.height)
            }
            let w = (v.width * fraction).rounded(.down)
            return CGRect(x: v.maxX - w, y: v.minY, width: w, height: v.height)
        case .topHalf:
            let h = index == 0 ? v.height - halfH : (v.height * fraction).rounded(.down)
            return CGRect(x: v.minX, y: v.maxY - h, width: v.width, height: h)
        case .bottomHalf:
            let h = index == 0 ? halfH : (v.height * fraction).rounded(.down)
            return CGRect(x: v.minX, y: v.minY, width: v.width, height: h)

        case .topLeftQuarter:
            return CGRect(x: v.minX, y: v.minY + halfH, width: halfW, height: v.height - halfH)
        case .topRightQuarter:
            return CGRect(x: v.minX + halfW, y: v.minY + halfH, width: v.width - halfW, height: v.height - halfH)
        case .bottomLeftQuarter:
            return CGRect(x: v.minX, y: v.minY, width: halfW, height: halfH)
        case .bottomRightQuarter:
            return CGRect(x: v.minX + halfW, y: v.minY, width: v.width - halfW, height: halfH)

        case .leftThird:
            return CGRect(x: v.minX, y: v.minY, width: thirdW, height: v.height)
        case .centerThird:
            return CGRect(x: v.minX + thirdW, y: v.minY, width: thirdW, height: v.height)
        case .rightThird:
            return CGRect(x: v.minX + 2 * thirdW, y: v.minY, width: v.width - 2 * thirdW, height: v.height)
        case .firstTwoThirds:
            return CGRect(x: v.minX, y: v.minY, width: 2 * thirdW, height: v.height)
        case .lastTwoThirds:
            return CGRect(x: v.minX + thirdW, y: v.minY, width: v.width - thirdW, height: v.height)

        case .firstFourth:
            return CGRect(x: v.minX, y: v.minY, width: fourthW, height: v.height)
        case .secondFourth:
            return CGRect(x: v.minX + fourthW, y: v.minY, width: fourthW, height: v.height)
        case .thirdFourth:
            return CGRect(x: v.minX + 2 * fourthW, y: v.minY, width: fourthW, height: v.height)
        case .lastFourth:
            return CGRect(x: v.minX + 3 * fourthW, y: v.minY, width: v.width - 3 * fourthW, height: v.height)
        case .firstThreeFourths:
            return CGRect(x: v.minX, y: v.minY, width: 3 * fourthW, height: v.height)
        case .lastThreeFourths:
            return CGRect(x: v.minX + fourthW, y: v.minY, width: v.width - fourthW, height: v.height)

        // Sixths: a 3×2 grid (top row above bottom row in Cocoa coords).
        case .topLeftSixth:
            return CGRect(x: v.minX, y: v.minY + halfH, width: thirdW, height: v.height - halfH)
        case .topCenterSixth:
            return CGRect(x: v.minX + thirdW, y: v.minY + halfH, width: thirdW, height: v.height - halfH)
        case .topRightSixth:
            return CGRect(x: v.minX + 2 * thirdW, y: v.minY + halfH, width: v.width - 2 * thirdW, height: v.height - halfH)
        case .bottomLeftSixth:
            return CGRect(x: v.minX, y: v.minY, width: thirdW, height: halfH)
        case .bottomCenterSixth:
            return CGRect(x: v.minX + thirdW, y: v.minY, width: thirdW, height: halfH)
        case .bottomRightSixth:
            return CGRect(x: v.minX + 2 * thirdW, y: v.minY, width: v.width - 2 * thirdW, height: halfH)

        case .maximize:
            return v
        case .almostMaximize:
            let w = (v.width * 0.9).rounded(.down)
            let h = (v.height * 0.9).rounded(.down)
            return CGRect(
                x: (v.midX - w / 2).rounded(),
                y: (v.midY - h / 2).rounded(),
                width: w,
                height: h
            )

        case .center, .maximizeHeight, .larger, .smaller,
             .moveLeft, .moveRight, .moveUp, .moveDown,
             .restore, .nextDisplay, .previousDisplay,
             .stashLeft, .stashRight, .unstashAll, .showThrowPanel:
            return nil
        }
    }
}
