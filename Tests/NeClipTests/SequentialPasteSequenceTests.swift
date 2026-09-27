import XCTest
@testable import NeClip

final class SequentialPasteSequenceTests: XCTestCase {
    private func claim(_ sequence: SequentialPasteSequence, _ ids: [Int64], now: Date = Date(),
                       file: StaticString = #filePath, line: UInt = #line) throws -> SequentialPasteSequence.Attempt {
        guard case .ready(let attempt) = sequence.beginNext(recentIDs: ids, now: now) else {
            XCTFail("Expected one claimed paste", file: file, line: line)
            throw NSError(domain: "test", code: 1)
        }
        return attempt
    }

    func testOverlappingPressCannotWriteOrCompleteTheSameItemTwice() throws {
        let sequence = SequentialPasteSequence()
        let first = try claim(sequence, [30, 20, 10])
        XCTAssertEqual(first.clipID, 30)
        XCTAssertEqual(sequence.beginNext(recentIDs: [99]), .busy)
        XCTAssertTrue(sequence.complete(first, advance: true))
        XCTAssertFalse(sequence.complete(first, advance: true))
        XCTAssertEqual(try claim(sequence, [99]).clipID, 20)
        XCTAssertEqual(sequence.snapshot(), .init(total: 3, position: 1))
    }

    func testFailedPasteOrFetchReleasesClaimAndRetriesSameItemWithNewToken() throws {
        let sequence = SequentialPasteSequence()
        let failed = try claim(sequence, [7, 8])
        XCTAssertTrue(sequence.complete(failed, advance: false))
        let retry = try claim(sequence, [9])
        XCTAssertEqual(retry.clipID, 7)
        XCTAssertNotEqual(failed, retry)
        XCTAssertFalse(sequence.complete(failed, advance: true))
        XCTAssertTrue(sequence.isCurrent(retry))
        XCTAssertEqual(sequence.snapshot().position, 0)
    }

    func testResetRejectsStaleCompletionEvenForSameClip() throws {
        let sequence = SequentialPasteSequence()
        let stale = try claim(sequence, [30, 20])
        sequence.noteExternalCapture()
        let fresh = try claim(sequence, [30, 10])
        XCTAssertFalse(sequence.isCurrent(stale))
        XCTAssertFalse(sequence.complete(stale, advance: false))
        XCTAssertFalse(sequence.complete(stale, advance: true))
        XCTAssertTrue(sequence.isCurrent(fresh))
        XCTAssertEqual(sequence.snapshot().position, 0)
        XCTAssertTrue(sequence.complete(fresh, advance: true))
        XCTAssertEqual(try claim(sequence, [99]).clipID, 10)
    }

    func testExpiryRejectsLateCompletionAndAllowsFreshSameClip() throws {
        let sequence = SequentialPasteSequence(timeout: 10)
        let start = Date(timeIntervalSince1970: 1_000)
        let stale = try claim(sequence, [30, 20], now: start)
        let expired = start.addingTimeInterval(10)
        XCTAssertFalse(sequence.complete(stale, advance: true, now: expired))
        let fresh = try claim(sequence, [30, 10], now: expired)
        XCTAssertFalse(sequence.complete(stale, advance: true, now: expired))
        XCTAssertTrue(sequence.isCurrent(fresh, now: expired))
        XCTAssertEqual(sequence.snapshot(now: expired).position, 0)
    }

    func testCompletionRestartsFromLatestHistoryAndEmptyDoesNotClaim() throws {
        let sequence = SequentialPasteSequence()
        XCTAssertEqual(sequence.beginNext(recentIDs: []), .empty)
        let first = try claim(sequence, [1])
        sequence.complete(first, advance: true)
        XCTAssertFalse(sequence.snapshot().isActive)
        XCTAssertEqual(try claim(sequence, [2, 1]).clipID, 2)
    }

    func testTimeoutAndCapacityKeepBoundedStableSnapshot() throws {
        let sequence = SequentialPasteSequence(capacity: 2, timeout: 10)
        let start = Date(timeIntervalSince1970: 1_000)
        let first = try claim(sequence, [4, 4, 5, 6], now: start)
        XCTAssertEqual(first.clipID, 4)
        sequence.complete(first, advance: true, now: start)
        let second = try claim(sequence, [6], now: start.addingTimeInterval(9))
        XCTAssertEqual(second.clipID, 5)
        sequence.complete(second, advance: true, now: start.addingTimeInterval(9))
        XCTAssertEqual(sequence.snapshot(now: start.addingTimeInterval(9)), .init(total: 2, position: 2))
        XCTAssertEqual(try claim(sequence, [9], now: start.addingTimeInterval(20)).clipID, 9)
    }
}
