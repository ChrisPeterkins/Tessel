import XCTest
@testable import Tessel

final class SnapZoneTests: XCTestCase {
    let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let config = SnapZone.Config(edgeThreshold: 10, cornerSize: 100)

    private func zone(_ x: CGFloat, _ y: CGFloat) -> SnapZone.Zone? {
        SnapZone.zone(at: CGPoint(x: x, y: y), screenFrame: frame, config: config)
    }

    func testMiddleOfScreenIsNoZone() {
        XCTAssertNil(zone(960, 540))
    }

    func testEdges() {
        XCTAssertEqual(zone(5, 540), .leftEdge)
        XCTAssertEqual(zone(1915, 540), .rightEdge)
        XCTAssertEqual(zone(960, 1075), .topEdge)
        XCTAssertEqual(zone(960, 5), .bottomEdge)
    }

    func testCornersViaVerticalEdges() {
        XCTAssertEqual(zone(5, 1020), .topLeftCorner)
        XCTAssertEqual(zone(1915, 1020), .topRightCorner)
        XCTAssertEqual(zone(5, 50), .bottomLeftCorner)
        XCTAssertEqual(zone(1915, 50), .bottomRightCorner)
    }

    func testCornersViaHorizontalEdges() {
        XCTAssertEqual(zone(50, 1075), .topLeftCorner)
        XCTAssertEqual(zone(1870, 1075), .topRightCorner)
        XCTAssertEqual(zone(50, 5), .bottomLeftCorner)
        XCTAssertEqual(zone(1870, 5), .bottomRightCorner)
    }

    func testJustInsideEdgeThresholdBoundary() {
        XCTAssertEqual(zone(10, 540), .leftEdge)
        XCTAssertNil(zone(11, 540))
    }

    func testDefaultZoneMapping() {
        XCTAssertEqual(Preferences.defaultZoneActions[.leftEdge], .leftHalf)
        XCTAssertEqual(Preferences.defaultZoneActions[.topEdge], .maximize)
        XCTAssertEqual(Preferences.defaultZoneActions[.bottomEdge], SnapAction?.none)
        XCTAssertEqual(Preferences.defaultZoneActions[.topLeftCorner], .topLeftQuarter)
    }
}
