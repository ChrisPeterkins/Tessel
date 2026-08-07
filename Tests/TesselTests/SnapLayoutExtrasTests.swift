import XCTest
@testable import Tessel

final class SnapLayoutExtrasTests: XCTestCase {
    let visible = CGRect(x: 0, y: 79, width: 1513, height: 883)

    func testFourthsTileExactly() {
        let fourths: [SnapAction] = [.firstFourth, .secondFourth, .thirdFourth, .lastFourth]
        let rects = fourths.map { SnapLayout.target(for: $0, on: visible)! }
        XCTAssertEqual(rects[0].minX, visible.minX)
        XCTAssertEqual(rects[0].maxX, rects[1].minX)
        XCTAssertEqual(rects[1].maxX, rects[2].minX)
        XCTAssertEqual(rects[2].maxX, rects[3].minX)
        XCTAssertEqual(rects[3].maxX, visible.maxX)
        XCTAssertEqual(rects.map(\.width).reduce(0, +), visible.width)
    }

    func testThreeFourths() {
        let first = SnapLayout.target(for: .firstThreeFourths, on: visible)!
        let last = SnapLayout.target(for: .lastThreeFourths, on: visible)!
        let firstFourth = SnapLayout.target(for: .firstFourth, on: visible)!
        XCTAssertEqual(first.minX, visible.minX)
        XCTAssertEqual(last.minX, firstFourth.maxX)
        XCTAssertEqual(last.maxX, visible.maxX)
    }

    func testSixthsTileExactly() {
        let sixths: [SnapAction] = [
            .topLeftSixth, .topCenterSixth, .topRightSixth,
            .bottomLeftSixth, .bottomCenterSixth, .bottomRightSixth,
        ]
        let rects = sixths.map { SnapLayout.target(for: $0, on: visible)! }
        XCTAssertEqual(rects.map(\.area).reduce(0, +), visible.area)
        // Top row sits above the bottom row.
        XCTAssertEqual(rects[0].minY, rects[3].maxY)
        // Rows span the full width.
        XCTAssertEqual(rects[2].maxX, visible.maxX)
        XCTAssertEqual(rects[5].maxX, visible.maxX)
        XCTAssertEqual(rects[0].maxY, visible.maxY)
        XCTAssertEqual(rects[3].minY, visible.minY)
    }

    func testAlmostMaximizeIsCenteredAt90Percent() {
        let rect = SnapLayout.target(for: .almostMaximize, on: visible)!
        XCTAssertEqual(rect.width, (visible.width * 0.9).rounded(.down))
        XCTAssertEqual(rect.height, (visible.height * 0.9).rounded(.down))
        XCTAssertEqual(rect.midX, visible.midX, accuracy: 1)
        XCTAssertEqual(rect.midY, visible.midY, accuracy: 1)
    }

    func testHalfCycling() {
        let half = SnapLayout.target(for: .leftHalf, on: visible, cycleIndex: 0)!
        let twoThirds = SnapLayout.target(for: .leftHalf, on: visible, cycleIndex: 1)!
        let oneThird = SnapLayout.target(for: .leftHalf, on: visible, cycleIndex: 2)!
        XCTAssertEqual(half.width, (visible.width / 2).rounded(.down))
        XCTAssertEqual(twoThirds.width, (visible.width * 2 / 3).rounded(.down))
        XCTAssertEqual(oneThird.width, (visible.width / 3).rounded(.down))
        // All anchored at the left edge.
        XCTAssertEqual(half.minX, visible.minX)
        XCTAssertEqual(twoThirds.minX, visible.minX)
        XCTAssertEqual(oneThird.minX, visible.minX)
    }

    func testRightHalfCyclingAnchorsRight() {
        let twoThirds = SnapLayout.target(for: .rightHalf, on: visible, cycleIndex: 1)!
        XCTAssertEqual(twoThirds.maxX, visible.maxX)
    }

    func testGapInsetsEdgesFullAndInteriorHalf() {
        let gap: CGFloat = 10
        let left = SnapLayout.target(for: .leftHalf, on: visible, gap: gap)!
        let right = SnapLayout.target(for: .rightHalf, on: visible, gap: gap)!
        // Screen-edge sides inset by the full gap.
        XCTAssertEqual(left.minX, visible.minX + gap)
        XCTAssertEqual(right.maxX, visible.maxX - gap)
        XCTAssertEqual(left.minY, visible.minY + gap)
        XCTAssertEqual(left.maxY, visible.maxY - gap)
        // Interior sides inset by half each → exactly one gap between tiles.
        XCTAssertEqual(right.minX - left.maxX, gap)
    }

    func testMaximizeWithGapStillInsets() {
        let gap: CGFloat = 8
        let rect = SnapLayout.target(for: .maximize, on: visible, gap: gap)!
        XCTAssertEqual(rect, visible.insetBy(dx: gap, dy: gap))
    }
}
