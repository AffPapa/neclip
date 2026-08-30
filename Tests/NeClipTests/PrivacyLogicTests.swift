import XCTest
@testable import NeClip

final class PrivacyLogicTests: XCTestCase {
    func testPasteboardAccessPolicyFailsClosedForUnknownAndDeniedStates() {
        XCTAssertEqual(
            ClipboardAccessPolicy.state(supportsPrivacyControl: false, rawBehavior: 3),
            .unrestricted
        )
        XCTAssertEqual(
            ClipboardAccessPolicy.state(supportsPrivacyControl: true, rawBehavior: 0),
            .needsChoice
        )
        XCTAssertEqual(
            ClipboardAccessPolicy.state(supportsPrivacyControl: true, rawBehavior: 1),
            .needsChoice
        )
        XCTAssertEqual(
            ClipboardAccessPolicy.state(supportsPrivacyControl: true, rawBehavior: 2),
            .allowed
        )
        XCTAssertEqual(
            ClipboardAccessPolicy.state(supportsPrivacyControl: true, rawBehavior: 3),
            .denied
        )
        XCTAssertEqual(
            ClipboardAccessPolicy.state(supportsPrivacyControl: true, rawBehavior: 99),
            .denied
        )
        XCTAssertFalse(ClipboardAccessState.denied.permitsBackgroundRead)
        XCTAssertTrue(ClipboardAccessState.allowed.permitsBackgroundRead)
    }
    override func tearDown() {
        Settings.ignoreNextCopy = false
        Settings.resumeCapture()
        super.tearDown()
    }

    func testClipboardWriteGuardConsumesOnlyExactOwnChangeCount() {
        let guardState = ClipboardWriteGuard(capacity: 2)
        guardState.markOwnWrite(changeCount: 41)

        XCTAssertFalse(guardState.consumeIfOwn(changeCount: 40))
        XCTAssertTrue(guardState.consumeIfOwn(changeCount: 41))
        XCTAssertFalse(guardState.consumeIfOwn(changeCount: 41))
    }

    func testClipboardWriteGuardEvictsOldCounts() {
        let guardState = ClipboardWriteGuard(capacity: 2)
        guardState.markOwnWrite(changeCount: 1)
        guardState.markOwnWrite(changeCount: 2)
        guardState.markOwnWrite(changeCount: 3)

        XCTAssertFalse(guardState.consumeIfOwn(changeCount: 1))
        XCTAssertTrue(guardState.consumeIfOwn(changeCount: 2))
        XCTAssertTrue(guardState.consumeIfOwn(changeCount: 3))
    }

    func testPasteDecisionMatrix() {
        XCTAssertEqual(
            PasteService.decision(copyOnly: true, accessibilityTrusted: true, targetPID: 10, currentPID: 10),
            .copyOnly
        )
        XCTAssertEqual(
            PasteService.decision(copyOnly: false, accessibilityTrusted: false, targetPID: 10, currentPID: 10),
            .copyOnlyNoAccessibility
        )
        XCTAssertEqual(
            PasteService.decision(copyOnly: false, accessibilityTrusted: true, targetPID: 10, currentPID: 11),
            .copyOnlyTargetChanged
        )
        XCTAssertEqual(
            PasteService.decision(copyOnly: false, accessibilityTrusted: true, targetPID: nil, currentPID: 10),
            .copyOnlyTargetChanged
        )
        XCTAssertEqual(
            PasteService.decision(copyOnly: false, accessibilityTrusted: true, targetPID: 10, currentPID: 10),
            .paste(10)
        )
    }

    func testPauseAndResumeArePersistedThroughSettingsAPI() {
        Settings.pause(until: nil)
        XCTAssertTrue(Settings.isCapturePaused)
        XCTAssertEqual(Settings.capturePauseState, .indefinite)

        let future = Date().addingTimeInterval(60)
        Settings.pause(until: future)
        XCTAssertTrue(Settings.isCapturePaused)
        guard case .until(let storedDate) = Settings.capturePauseState else {
            return XCTFail("Expected a timed pause")
        }
        XCTAssertEqual(storedDate.timeIntervalSince1970, future.timeIntervalSince1970, accuracy: 0.01)

        Settings.resumeCapture()
        XCTAssertFalse(Settings.isCapturePaused)
        XCTAssertEqual(Settings.capturePauseState, .active)
    }

    func testExpiredPauseResumesCapture() {
        Settings.pause(until: Date().addingTimeInterval(-1))
        XCTAssertFalse(Settings.isCapturePaused)
        XCTAssertEqual(Settings.capturePauseState, .active)
    }

    func testIgnoreNextCopyIsConsumedExactlyOnce() {
        Settings.ignoreNextCopy = true
        XCTAssertTrue(Settings.consumeIgnoreNextCopy())
        XCTAssertFalse(Settings.consumeIgnoreNextCopy())
        XCTAssertFalse(Settings.ignoreNextCopy)
    }

    func testExcludedSourcePolicyFailsClosed() {
        let excluded: Set<String> = ["com.example.passwords"]

        XCTAssertTrue(ClipboardCapturePolicy.shouldRejectSource(
            bundleID: nil,
            excludedTransitionActive: false,
            excludedApps: excluded
        ))
        XCTAssertTrue(ClipboardCapturePolicy.shouldRejectSource(
            bundleID: "com.example.passwords",
            excludedTransitionActive: false,
            excludedApps: excluded
        ))
        XCTAssertTrue(ClipboardCapturePolicy.shouldRejectSource(
            bundleID: "com.example.notes",
            excludedTransitionActive: true,
            excludedApps: excluded
        ))
        XCTAssertFalse(ClipboardCapturePolicy.shouldRejectSource(
            bundleID: "com.example.notes",
            excludedTransitionActive: false,
            excludedApps: excluded
        ))
    }

    func testExcludedChangeCountSurvivesDelayedTimerTick() {
        var guardState = ClipboardExcludedChangeGuard(capacity: 2)
        guardState.record(changeCount: 70)

        XCTAssertFalse(guardState.consumeIfExcluded(changeCount: 71))
        XCTAssertTrue(guardState.consumeIfExcluded(changeCount: 70))
        XCTAssertFalse(guardState.consumeIfExcluded(changeCount: 70))
    }

    func testExcludedChangeGuardBoundsPendingGenerations() {
        var guardState = ClipboardExcludedChangeGuard(capacity: 2)
        guardState.record(changeCount: 1)
        guardState.record(changeCount: 2)
        guardState.record(changeCount: 3)

        XCTAssertFalse(guardState.consumeIfExcluded(changeCount: 1))
        XCTAssertTrue(guardState.consumeIfExcluded(changeCount: 2))
        XCTAssertTrue(guardState.consumeIfExcluded(changeCount: 3))
    }

    func testImagePolicyLimitsEncodedBytesAndDecodedPixels() {
        XCTAssertTrue(ClipboardCapturePolicy.acceptsImage(
            byteCount: 1_024,
            width: 4_000,
            height: 4_000
        ))
        XCTAssertFalse(ClipboardCapturePolicy.acceptsImage(
            byteCount: ClipboardCapturePolicy.maxEncodedImageBytes + 1,
            width: 100,
            height: 100
        ))
        XCTAssertFalse(ClipboardCapturePolicy.acceptsImage(
            byteCount: 1_024,
            width: ClipboardCapturePolicy.maxImagePixels,
            height: 2
        ))
    }
}
