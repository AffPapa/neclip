import AppKit
import XCTest
@testable import NeClip

final class ScreenshotCancellationTests: XCTestCase {
    @MainActor
    private final class PendingOperation {
        var continuation: CheckedContinuation<Void, Never>?
        func suspend() async {
            await withCheckedContinuation { continuation = $0 }
        }
        func finish() { continuation?.resume(); continuation = nil }
    }

    @MainActor
    func testCancelledNonCooperativeCaptureCannotBlockOrClearReplacement() async throws {
        let board = NSPasteboard(name: .init("neclip-capture-cancel-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let coordinator = ScreenshotCoordinator(monitor: ClipboardMonitor(pasteboard: board, storage: storage))
        let old = PendingOperation(), replacement = PendingOperation()
        let oldStarted = expectation(description: "old started")
        let oldFinished = expectation(description: "old finished")
        coordinator.performCaptureOperation { generation in
            oldStarted.fulfill()
            await old.suspend() // Intentionally ignores cancellation like a delayed system callback.
            XCTAssertFalse(coordinator.isCurrentCapture(generation), "Late result/error must not reach UI")
            oldFinished.fulfill()
        }
        await fulfillment(of: [oldStarted], timeout: 2)
        XCTAssertTrue(coordinator.isCapturing)
        coordinator.cancel()
        XCTAssertFalse(coordinator.isCapturing, "Cancel must release the launch guard immediately")

        let newStarted = expectation(description: "replacement started")
        let newFinished = expectation(description: "replacement finished")
        coordinator.performCaptureOperation { generation in
            newStarted.fulfill()
            await replacement.suspend()
            XCTAssertTrue(coordinator.isCurrentCapture(generation))
            newFinished.fulfill()
        }
        await fulfillment(of: [newStarted], timeout: 2)
        old.finish()
        await fulfillment(of: [oldFinished], timeout: 2)
        XCTAssertTrue(coordinator.isCapturing, "Stale defer must not clear the replacement")
        replacement.finish()
        await fulfillment(of: [newFinished], timeout: 2)
        XCTAssertFalse(coordinator.isCapturing)
        coordinator.cancel()
        XCTAssertEqual(storage.count, 0)
    }
}
