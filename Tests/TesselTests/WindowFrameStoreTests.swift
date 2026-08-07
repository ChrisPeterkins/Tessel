import XCTest
@testable import Tessel

final class WindowFrameStoreTests: XCTestCase {
    let id: CGWindowID = 42
    let userFrame = CGRect(x: 300, y: 200, width: 900, height: 700)
    let leftHalf = CGRect(x: 0, y: 0, width: 960, height: 1080)
    let rightHalf = CGRect(x: 960, y: 0, width: 960, height: 1080)

    func testRestoreAfterChainedSnapsReturnsOriginalFrame() {
        let store = WindowFrameStore()
        // Snap to left half from the hand-placed frame…
        store.recordIfNeeded(id, currentFrame: userFrame)
        store.didApply(id, frame: leftHalf, action: .leftHalf)
        // …then snap to right half without the user moving anything.
        store.recordIfNeeded(id, currentFrame: leftHalf)
        store.didApply(id, frame: rightHalf, action: .rightHalf)

        XCTAssertEqual(store.savedFrame(for: id), userFrame)
    }

    func testManualMoveAfterSnapBecomesNewRestoreTarget() {
        let store = WindowFrameStore()
        store.recordIfNeeded(id, currentFrame: userFrame)
        store.didApply(id, frame: leftHalf, action: .leftHalf)

        // User drags the window somewhere new, then snaps again.
        let movedFrame = CGRect(x: 500, y: 100, width: 800, height: 600)
        store.recordIfNeeded(id, currentFrame: movedFrame)
        store.didApply(id, frame: rightHalf, action: .rightHalf)

        XCTAssertEqual(store.savedFrame(for: id), movedFrame)
    }

    func testSmallFrameJitterStillCountsAsSnapped() {
        let store = WindowFrameStore()
        store.recordIfNeeded(id, currentFrame: userFrame)
        store.didApply(id, frame: leftHalf, action: .leftHalf)

        // Apps sometimes report frames off by a point.
        let jittered = leftHalf.offsetBy(dx: 1, dy: -1)
        store.recordIfNeeded(id, currentFrame: jittered)

        XCTAssertEqual(store.savedFrame(for: id), userFrame)
    }

    func testLastActionTracked() {
        let store = WindowFrameStore()
        store.recordIfNeeded(id, currentFrame: userFrame)
        store.didApply(id, frame: leftHalf, action: .leftHalf)
        XCTAssertEqual(store.lastAction(for: id), .leftHalf)
        XCTAssertEqual(store.lastAppliedFrame(for: id), leftHalf)
    }
}
