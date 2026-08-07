import XCTest
@testable import Tessel

final class SnapLayoutTests: XCTestCase {
    // A realistic visibleFrame: Dock on the bottom (y offset), odd width to
    // exercise the floor-and-remainder math.
    let visible = CGRect(x: 0, y: 79, width: 1513, height: 883)

    func testHalvesTileExactly() {
        let left = SnapLayout.target(for: .leftHalf, on: visible)!
        let right = SnapLayout.target(for: .rightHalf, on: visible)!
        XCTAssertEqual(left.minX, visible.minX)
        XCTAssertEqual(left.maxX, right.minX)
        XCTAssertEqual(right.maxX, visible.maxX)
        XCTAssertEqual(left.height, visible.height)
        XCTAssertEqual(right.height, visible.height)

        let top = SnapLayout.target(for: .topHalf, on: visible)!
        let bottom = SnapLayout.target(for: .bottomHalf, on: visible)!
        XCTAssertEqual(bottom.minY, visible.minY)
        XCTAssertEqual(bottom.maxY, top.minY)
        XCTAssertEqual(top.maxY, visible.maxY)
    }

    func testTopHalfIsAboveBottomHalf() {
        // Cocoa coords: top = larger Y.
        let top = SnapLayout.target(for: .topHalf, on: visible)!
        let bottom = SnapLayout.target(for: .bottomHalf, on: visible)!
        XCTAssertGreaterThan(top.midY, bottom.midY)
    }

    func testQuartersTileExactly() {
        let tl = SnapLayout.target(for: .topLeftQuarter, on: visible)!
        let tr = SnapLayout.target(for: .topRightQuarter, on: visible)!
        let bl = SnapLayout.target(for: .bottomLeftQuarter, on: visible)!
        let br = SnapLayout.target(for: .bottomRightQuarter, on: visible)!
        XCTAssertEqual(tl.area + tr.area + bl.area + br.area, visible.area)
        XCTAssertEqual(tl.maxX, tr.minX)
        XCTAssertEqual(bl.maxY, tl.minY)
        XCTAssertEqual(br.maxX, visible.maxX)
        XCTAssertEqual(br.minY, visible.minY)
        XCTAssertEqual(tr.maxY, visible.maxY)
    }

    func testThirdsTileExactly() {
        let left = SnapLayout.target(for: .leftThird, on: visible)!
        let center = SnapLayout.target(for: .centerThird, on: visible)!
        let right = SnapLayout.target(for: .rightThird, on: visible)!
        XCTAssertEqual(left.minX, visible.minX)
        XCTAssertEqual(left.maxX, center.minX)
        XCTAssertEqual(center.maxX, right.minX)
        XCTAssertEqual(right.maxX, visible.maxX)
        XCTAssertEqual(left.width + center.width + right.width, visible.width)
    }

    func testTwoThirds() {
        let first = SnapLayout.target(for: .firstTwoThirds, on: visible)!
        let last = SnapLayout.target(for: .lastTwoThirds, on: visible)!
        let leftThird = SnapLayout.target(for: .leftThird, on: visible)!
        XCTAssertEqual(first.minX, visible.minX)
        XCTAssertEqual(last.minX, leftThird.maxX)
        XCTAssertEqual(last.maxX, visible.maxX)
    }

    func testMaximizeIsVisibleFrame() {
        XCTAssertEqual(SnapLayout.target(for: .maximize, on: visible), visible)
    }

    func testNonFrameActionsReturnNil() {
        XCTAssertNil(SnapLayout.target(for: .restore, on: visible))
        XCTAssertNil(SnapLayout.target(for: .nextDisplay, on: visible))
        XCTAssertNil(SnapLayout.target(for: .previousDisplay, on: visible))
    }
}
