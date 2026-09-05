import XCTest
@testable import NeClip

final class CaptureResumeTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) rethrows {
        let suite = "org.affpapa.neclip.tests.capture-resume.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let arguments = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defer {
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            defaults.removePersistentDomain(forName: suite)
        }
        defaults.setVolatileDomain([:], forName: UserDefaults.argumentDomain)
        try body(defaults)
    }

    func testPersistentPauseResumesWithoutChangingOtherPreferences() {
        withDefaults { defaults in
            defaults.set(true, forKey: CapturePausePreferences.indefiniteKey)
            defaults.set(Date().addingTimeInterval(900), forKey: CapturePausePreferences.untilKey)
            defaults.set(true, forKey: "automaticLayoutCorrection")
            defaults.set(true, forKey: "rememberLayoutPerApplication")
            XCTAssertFalse(CapturePausePreferences.isLaunchLocked(in: defaults))

            CapturePausePreferences.resume(in: defaults)

            XCTAssertFalse(defaults.bool(forKey: CapturePausePreferences.indefiniteKey))
            XCTAssertNil(defaults.object(forKey: CapturePausePreferences.untilKey))
            XCTAssertTrue(defaults.bool(forKey: "automaticLayoutCorrection"))
            XCTAssertTrue(defaults.bool(forKey: "rememberLayoutPerApplication"))
        }
    }

    func testLaunchPauseSurvivesResumeAndPreservesOtherSafetyOverrides() {
        withDefaults { defaults in
            let arguments = [
                CapturePausePreferences.indefiniteKey: "YES",
                "automaticLayoutCorrection": "NO",
                "rememberLayoutPerApplication": "NO"
            ]
            defaults.set(true, forKey: CapturePausePreferences.indefiniteKey)
            defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            XCTAssertTrue(CapturePausePreferences.isLaunchLocked(in: defaults))

            CapturePausePreferences.resume(in: defaults)

            XCTAssertTrue(defaults.bool(forKey: CapturePausePreferences.indefiniteKey))
            XCTAssertTrue(CapturePausePreferences.isLaunchLocked(in: defaults))
            XCTAssertFalse(defaults.bool(forKey: "automaticLayoutCorrection"))
            XCTAssertFalse(defaults.bool(forKey: "rememberLayoutPerApplication"))
            XCTAssertEqual(defaults.volatileDomain(forName: UserDefaults.argumentDomain) as NSDictionary, arguments as NSDictionary)
        }
    }

    func testFalseOrAbsentLaunchFlagDoesNotLockOrdinaryPause() {
        withDefaults { defaults in
            for value in ["NO", "false", "0"] {
                defaults.setVolatileDomain([CapturePausePreferences.indefiniteKey: value], forName: UserDefaults.argumentDomain)
                XCTAssertFalse(CapturePausePreferences.isLaunchLocked(in: defaults))
            }
            defaults.setVolatileDomain([CapturePausePreferences.indefiniteKey: true], forName: UserDefaults.argumentDomain)
            XCTAssertTrue(CapturePausePreferences.isLaunchLocked(in: defaults))
            defaults.setVolatileDomain([:], forName: UserDefaults.argumentDomain)
            XCTAssertFalse(CapturePausePreferences.isLaunchLocked(in: defaults))
        }
    }
}
