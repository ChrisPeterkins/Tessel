import CoreGraphics

enum SnapAction: String, CaseIterable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    case leftThird, centerThird, rightThird, firstTwoThirds, lastTwoThirds
    case firstFourth, secondFourth, thirdFourth, lastFourth
    case firstThreeFourths, lastThreeFourths
    case topLeftSixth, topCenterSixth, topRightSixth
    case bottomLeftSixth, bottomCenterSixth, bottomRightSixth
    case maximize, almostMaximize, maximizeHeight
    case center, larger, smaller
    case moveLeft, moveRight, moveUp, moveDown
    case restore
    case nextDisplay, previousDisplay
    case stashLeft, stashRight, unstashAll
    case showThrowPanel

    var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeftQuarter: return "Top Left Quarter"
        case .topRightQuarter: return "Top Right Quarter"
        case .bottomLeftQuarter: return "Bottom Left Quarter"
        case .bottomRightQuarter: return "Bottom Right Quarter"
        case .leftThird: return "Left Third"
        case .centerThird: return "Center Third"
        case .rightThird: return "Right Third"
        case .firstTwoThirds: return "First Two Thirds"
        case .lastTwoThirds: return "Last Two Thirds"
        case .firstFourth: return "First Fourth"
        case .secondFourth: return "Second Fourth"
        case .thirdFourth: return "Third Fourth"
        case .lastFourth: return "Last Fourth"
        case .firstThreeFourths: return "First Three Fourths"
        case .lastThreeFourths: return "Last Three Fourths"
        case .topLeftSixth: return "Top Left Sixth"
        case .topCenterSixth: return "Top Center Sixth"
        case .topRightSixth: return "Top Right Sixth"
        case .bottomLeftSixth: return "Bottom Left Sixth"
        case .bottomCenterSixth: return "Bottom Center Sixth"
        case .bottomRightSixth: return "Bottom Right Sixth"
        case .maximize: return "Maximize"
        case .almostMaximize: return "Almost Maximize"
        case .maximizeHeight: return "Maximize Height"
        case .center: return "Center"
        case .larger: return "Make Larger"
        case .smaller: return "Make Smaller"
        case .moveLeft: return "Move to Left Edge"
        case .moveRight: return "Move to Right Edge"
        case .moveUp: return "Move to Top Edge"
        case .moveDown: return "Move to Bottom Edge"
        case .restore: return "Restore"
        case .nextDisplay: return "Next Display"
        case .previousDisplay: return "Previous Display"
        case .stashLeft: return "Stash Left"
        case .stashRight: return "Stash Right"
        case .unstashAll: return "Unstash All"
        case .showThrowPanel: return "Window Throw Panel"
        }
    }

    /// Actions whose target is a fixed region of the screen, independent of the
    /// window's current frame. These are the ones drag zones may map to.
    var isFixedLayout: Bool {
        SnapLayout.target(for: self, on: CGRect(x: 0, y: 0, width: 1000, height: 1000)) != nil
    }
}
