import XCTest
@testable import NeClip

final class SequentialPasteQueueTests: XCTestCase {
    func testAcceptedClipsAreCollectedOnlyWhileEnabled() {
        let queue = SequentialPasteQueue()
        XCTAssertFalse(queue.appendAcceptedClip(id: 1))
        queue.startCollecting()
        XCTAssertTrue(queue.appendAcceptedClip(id: 2))
        queue.stopCollecting()
        XCTAssertFalse(queue.appendAcceptedClip(id: 3))
        XCTAssertEqual(queue.snapshot, .init(isCollecting: false, total: 1, position: 0))
    }

    func testManualAppendAndSuccessfulAdvance() {
        let queue = SequentialPasteQueue()
        XCTAssertTrue(queue.appendManual(id: 10))
        XCTAssertTrue(queue.appendManual(id: 20))
        XCTAssertEqual(queue.beginNext(), 10)
        XCTAssertEqual(queue.beginNext(), 10)
        queue.complete(id: 10, advance: true)
        XCTAssertEqual(queue.beginNext(), 20)
        queue.complete(id: 20, advance: true)
        XCTAssertNil(queue.beginNext())
        XCTAssertEqual(queue.snapshot.remaining, 0)
    }

    func testFailedPasteKeepsCurrentItemAndResetRewinds() {
        let queue = SequentialPasteQueue()
        queue.appendManual(id: 7)
        queue.appendManual(id: 8)
        XCTAssertEqual(queue.beginNext(), 7)
        queue.complete(id: 7, advance: false)
        XCTAssertEqual(queue.beginNext(), 7)
        queue.complete(id: 7, advance: true)
        XCTAssertEqual(queue.beginNext(), 8)
        queue.reset()
        XCTAssertEqual(queue.beginNext(), 7)
    }

    func testClearAndBoundedCapacity() {
        let queue = SequentialPasteQueue(capacity: 2)
        XCTAssertTrue(queue.appendManual(id: 1))
        XCTAssertTrue(queue.appendManual(id: 2))
        XCTAssertFalse(queue.appendManual(id: 3))
        queue.complete(id: queue.beginNext()!, advance: true)
        XCTAssertTrue(queue.appendManual(id: 3))
        XCTAssertEqual(queue.snapshot.total, 2)
        XCTAssertEqual(queue.beginNext(), 2)
        queue.clear()
        XCTAssertEqual(queue.snapshot, .init(isCollecting: false, total: 0, position: 0))
    }
}
