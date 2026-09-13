import XCTest
@testable import NeClip

final class OptionKeyCorrectionTests: XCTestCase {
    func testStandaloneOptionReleaseTriggersCorrection() {
        var policy = OptionKeyGesturePolicy()

        XCTAssertFalse(policy.handle(.optionChanged(isDown: true, hasOtherModifier: false)))
        XCTAssertTrue(policy.handle(.optionChanged(isDown: false, hasOtherModifier: false)))
        XCTAssertFalse(policy.optionHeld)
    }

    func testOptionWithTypingDoesNotTrigger() {
        var policy = OptionKeyGesturePolicy()

        _ = policy.handle(.optionChanged(isDown: true, hasOtherModifier: false))
        _ = policy.handle(.otherInput)
        XCTAssertFalse(policy.handle(.optionChanged(isDown: false, hasOtherModifier: false)))
    }

    func testOptionWithOtherModifierOrMouseDoesNotTrigger() {
        var policy = OptionKeyGesturePolicy()
        _ = policy.handle(.optionChanged(isDown: true, hasOtherModifier: true))
        XCTAssertFalse(policy.handle(.optionChanged(isDown: false, hasOtherModifier: true)))

        _ = policy.handle(.optionChanged(isDown: true, hasOtherModifier: false))
        _ = policy.handle(.otherInput)
        XCTAssertFalse(policy.handle(.optionChanged(isDown: false, hasOtherModifier: false)))
    }

    func testOtherModifierPressedAfterOptionCancelsGesture() {
        var policy = OptionKeyGesturePolicy()
        _ = policy.handle(.optionChanged(isDown: true, hasOtherModifier: false))
        _ = policy.handle(.otherModifierChanged(hasOtherModifier: true))
        XCTAssertFalse(policy.handle(.optionChanged(isDown: false, hasOtherModifier: false)))
    }
}
