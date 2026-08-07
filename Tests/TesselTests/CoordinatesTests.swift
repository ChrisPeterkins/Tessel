import XCTest
@testable import Tessel

final class CoordinatesTests: XCTestCase {
    let primaryMaxY: CGFloat = 1080 // primary screen height

    func testFrameRoundTrip() {
        let cocoa = CGRect(x: 100, y: 200, width: 400, height: 300)
        let ax = Coordinates.axFrame(fromCocoa: cocoa, primaryMaxY: primaryMaxY)
        XCTAssertEqual(ax, CGRect(x: 100, y: 1080 - 500, width: 400, height: 300))
        XCTAssertEqual(Coordinates.cocoaFrame(fromAX: ax, primaryMaxY: primaryMaxY), cocoa)
    }

    func testFrameAtTopOfPrimaryScreen() {
        // A window at the very top of the primary screen has AX y == 0.
        let cocoa = CGRect(x: 0, y: 1080 - 300, width: 400, height: 300)
        let ax = Coordinates.axFrame(fromCocoa: cocoa, primaryMaxY: primaryMaxY)
        XCTAssertEqual(ax.minY, 0)
    }

    func testSecondaryScreenLeftOfPrimary() {
        // A display left of the primary: negative X in both spaces.
        let cocoa = CGRect(x: -1920, y: 0, width: 800, height: 600)
        let ax = Coordinates.axFrame(fromCocoa: cocoa, primaryMaxY: primaryMaxY)
        XCTAssertEqual(ax.minX, -1920)
        XCTAssertEqual(Coordinates.cocoaFrame(fromAX: ax, primaryMaxY: primaryMaxY), cocoa)
    }

    func testScreenAbovePrimaryHasNegativeAXY() {
        // A display above the primary: positive Cocoa Y, negative AX Y.
        let cocoa = CGRect(x: 0, y: 1080, width: 400, height: 300)
        let ax = Coordinates.axFrame(fromCocoa: cocoa, primaryMaxY: primaryMaxY)
        XCTAssertEqual(ax.minY, -300)
        XCTAssertEqual(Coordinates.cocoaFrame(fromAX: ax, primaryMaxY: primaryMaxY), cocoa)
    }

    func testPointRoundTrip() {
        let cocoa = CGPoint(x: 250, y: 900)
        let ax = Coordinates.axPoint(fromCocoa: cocoa, primaryMaxY: primaryMaxY)
        XCTAssertEqual(ax, CGPoint(x: 250, y: 180))
        XCTAssertEqual(Coordinates.cocoaPoint(fromAX: ax, primaryMaxY: primaryMaxY), cocoa)
    }
}
