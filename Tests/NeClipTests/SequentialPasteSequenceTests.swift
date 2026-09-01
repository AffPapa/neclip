import XCTest
@testable import NeClip

final class SequentialPasteSequenceTests: XCTestCase {
    func testSequenceStartsFromRecentHistoryAndAdvances() {
        let sequence = SequentialPasteSequence()
        XCTAssertEqual(sequence.beginNext(recentIDs: [30, 20, 10]), 30)
        XCTAssertEqual(sequence.beginNext(recentIDs: [99]), 30)
        sequence.complete(id: 30, advance: true)
        XCTAssertEqual(sequence.beginNext(recentIDs: [99]), 20)
        XCTAssertEqual(sequence.snapshot(), .init(total: 3, position: 1))
    }

    func testFailedPasteKeepsCurrentItem() {
        let sequence = SequentialPasteSequence()
        XCTAssertEqual(sequence.beginNext(recentIDs: [7, 8]), 7)
        sequence.complete(id: 7, advance: false)
        XCTAssertEqual(sequence.beginNext(recentIDs: [9]), 7)
    }

    func testCompletionRestartsFromLatestHistory() {
        let sequence = SequentialPasteSequence()
        XCTAssertEqual(sequence.beginNext(recentIDs: [1]), 1)
        sequence.complete(id: 1, advance: true)
        XCTAssertFalse(sequence.snapshot().isActive)
        XCTAssertEqual(sequence.beginNext(recentIDs: [2, 1]), 2)
    }

    func testTimeoutAndExternalCaptureStartAFreshSequence() {
        let sequence = SequentialPasteSequence(timeout: 10)
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(sequence.beginNext(recentIDs: [1, 2], now: start), 1)
        sequence.complete(id: 1, advance: true, now: start)
        XCTAssertEqual(sequence.beginNext(recentIDs: [9], now: start.addingTimeInterval(9)), 2)
        sequence.complete(id: 2, advance: true, now: start.addingTimeInterval(9))
        XCTAssertEqual(sequence.beginNext(recentIDs: [9], now: start.addingTimeInterval(20)), 9)

        sequence.noteExternalCapture()
        XCTAssertFalse(sequence.isCurrent(id: 9, now: start.addingTimeInterval(21)))
        XCTAssertEqual(sequence.beginNext(recentIDs: [8, 9], now: start.addingTimeInterval(21)), 8)
    }

    func testCapacityAndDuplicateIDsAreBounded() {
        let sequence = SequentialPasteSequence(capacity: 2)
        XCTAssertEqual(sequence.beginNext(recentIDs: [4, 4, 5, 6]), 4)
        sequence.complete(id: 4, advance: true)
        XCTAssertEqual(sequence.beginNext(recentIDs: [6]), 5)
        sequence.complete(id: 5, advance: true)
        XCTAssertEqual(sequence.snapshot(), .init(total: 2, position: 2))
    }
}
