import Foundation
import XCTest
@testable import NeClip

final class HistoryCleanupCoordinatorTests: XCTestCase {
    private final class Events: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [String] = []
        var values: [String] { lock.withLock { storage } }
        func add(_ value: String) { lock.withLock { storage.append(value) } }
    }

    @MainActor
    private final class Capture: HistoryCaptureControlling {
        var isRunning: Bool
        var starts = 0
        var stops = 0
        private let queue: DispatchQueue
        private var stoppedWaiter: CheckedContinuation<Void, Never>?

        init(running: Bool, queue: DispatchQueue = DispatchQueue(label: "neclip.test.cleanup")) {
            isRunning = running
            self.queue = queue
        }

        func start() {
            isRunning = true
            starts += 1
        }

        func stopAndDrainAsync() async {
            isRunning = false
            stops += 1
            stoppedWaiter?.resume()
            stoppedWaiter = nil
            await withCheckedContinuation { continuation in
                queue.async { continuation.resume() }
            }
        }

        func waitUntilStopped() async {
            if stops > 0 { return }
            await withCheckedContinuation { stoppedWaiter = $0 }
        }
    }

    @MainActor
    func testQueuedSnapshotFinishesBeforeDeletionWithoutBlockingMainActor() async throws {
        let queue = DispatchQueue(label: "neclip.test.cleanup.blocked")
        let release = DispatchSemaphore(value: 0)
        let events = Events()
        queue.async {
            release.wait()
            events.add("old snapshot inserted")
        }
        let capture = Capture(running: true, queue: queue)
        let coordinator = HistoryCleanupCoordinator(capture: capture)
        let cleanup = Task {
            try await coordinator.run {
                events.add("delete")
                return 42
            }
        }
        await capture.waitUntilStopped()
        XCTAssertFalse(capture.isRunning)
        XCTAssertTrue(events.values.isEmpty)
        // Execution reaches here while the worker is blocked: the main actor
        // remains available for UI rather than waiting in processingQueue.sync.
        release.signal()
        let value = try await cleanup.value
        XCTAssertEqual(value, 42)
        XCTAssertEqual(events.values, ["old snapshot inserted", "delete"])
        XCTAssertTrue(capture.isRunning)
        XCTAssertEqual(capture.starts, 1)
    }

    @MainActor
    func testFailureRestoresOnlyPreviouslyRunningObservation() async {
        enum ExpectedFailure: Error { case sample }
        for running in [true, false] {
            let capture = Capture(running: running)
            let coordinator = HistoryCleanupCoordinator(capture: capture)
            do {
                try await coordinator.run { throw ExpectedFailure.sample }
                XCTFail("Expected cleanup failure")
            } catch {
                XCTAssertTrue(error is ExpectedFailure)
            }
            XCTAssertEqual(capture.isRunning, running)
            XCTAssertEqual(capture.starts, running ? 1 : 0)
        }
    }

    @MainActor
    func testConcurrentRequestsSerializeThroughTheSameCaptureBarrier() async throws {
        let queue = DispatchQueue(label: "neclip.test.cleanup.serial")
        let release = DispatchSemaphore(value: 0)
        queue.async { release.wait() }
        let events = Events()
        let capture = Capture(running: true, queue: queue)
        let coordinator = HistoryCleanupCoordinator(capture: capture)
        let first = Task { try await coordinator.run { events.add("first") } }
        await capture.waitUntilStopped()
        let second = Task { try await coordinator.run { events.add("second") } }
        await Task.yield()
        XCTAssertEqual(capture.stops, 1)
        XCTAssertTrue(events.values.isEmpty)
        release.signal()
        try await first.value
        try await second.value
        XCTAssertEqual(events.values, ["first", "second"])
        XCTAssertEqual(capture.starts, 2)
        XCTAssertTrue(capture.isRunning)
    }

    @MainActor
    func testMissingCaptureFailsWithoutRunningDeletion() async {
        let coordinator = HistoryCleanupCoordinator()
        let events = Events()
        do {
            try await coordinator.run { events.add("delete") }
            XCTFail("Unattached coordinator must not claim safe cleanup")
        } catch {
            XCTAssertTrue(error is HistoryCleanupError)
        }
        XCTAssertTrue(events.values.isEmpty)
    }
}
