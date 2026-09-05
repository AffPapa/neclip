import Carbon.HIToolbox
import Foundation
import XCTest
@testable import NeClip

final class GlobalHotKeyDispatchTests: XCTestCase {
    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = 0

        var value: Int { lock.withLock { storage } }
        func increment() { lock.withLock { storage += 1 } }
    }

    @MainActor
    func testOwnedPressReturnsBeforeExecutingExactlyOnceOnMainQueue() {
        let counter = Counter()
        let completed = expectation(description: "Own action runs on main queue")
        let queueDrained = expectation(description: "Queued action completed")
        let status = GlobalHotKey.dispatch(
            eventKind: UInt32(kEventHotKeyPressed),
            received: EventHotKeyID(signature: GlobalHotKey.signature, id: 42),
            identifier: 42
        ) {
            XCTAssertTrue(Thread.isMainThread)
            counter.increment()
            completed.fulfill()
        }

        XCTAssertEqual(status, noErr)
        XCTAssertEqual(counter.value, 0, "Carbon must return before the action opens a menu")
        DispatchQueue.main.async { queueDrained.fulfill() }
        wait(for: [completed, queueDrained], timeout: 1, enforceOrder: true)
        XCTAssertEqual(counter.value, 1)
    }

    @MainActor
    func testForeignIdentifiersSignaturesAndReleasesAreNotConsumedOrDispatched() {
        let counter = Counter()
        let queueDrained = expectation(description: "No action was queued")
        let events: [(UInt32, EventHotKeyID)] = [
            (UInt32(kEventHotKeyPressed), EventHotKeyID(signature: GlobalHotKey.signature, id: 7)),
            (UInt32(kEventHotKeyPressed), EventHotKeyID(signature: 0, id: 42)),
            (UInt32(kEventHotKeyReleased), EventHotKeyID(signature: GlobalHotKey.signature, id: 42)),
            (UInt32(kEventRawKeyDown), EventHotKeyID(signature: GlobalHotKey.signature, id: 42))
        ]
        for (kind, received) in events {
            XCTAssertEqual(GlobalHotKey.dispatch(
                eventKind: kind,
                received: received,
                identifier: 42,
                action: { counter.increment() }
            ), OSStatus(eventNotHandledErr))
        }
        DispatchQueue.main.async { queueDrained.fulfill() }
        wait(for: [queueDrained], timeout: 1)
        XCTAssertEqual(counter.value, 0)
    }
}
