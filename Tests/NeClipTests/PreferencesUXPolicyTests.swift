import ServiceManagement
import XCTest
@testable import NeClip

final class PreferencesUXPolicyTests: XCTestCase {
    func testLoginItemApprovalIsNotReportedAsOperational() {
        let pending = LoginItemPresentation(status: .requiresApproval)
        XCTAssertTrue(pending.isRequested)
        XCTAssertTrue(pending.needsApproval)
        XCTAssertNotNil(pending.detail)
        let enabled = LoginItemPresentation(status: .enabled)
        XCTAssertTrue(enabled.isRequested)
        XCTAssertFalse(enabled.needsApproval)
        XCTAssertNil(enabled.detail)
    }

    func testDisabledAndMissingLoginItemsAreNotRequested() {
        let disabled = LoginItemPresentation(status: .notRegistered)
        XCTAssertFalse(disabled.isRequested)
        XCTAssertFalse(disabled.needsApproval)
        let missing = LoginItemPresentation(status: .notFound)
        XCTAssertFalse(missing.isRequested)
        XCTAssertNotNil(missing.detail)
    }

    func testProgressCannotExpireUntilOperationFinishes() {
        XCTAssertFalse(PreferencesFeedbackPolicy.shouldExpire(
            current: "Выполняется…", expected: "Выполняется…", operationRunning: true
        ))
        XCTAssertTrue(PreferencesFeedbackPolicy.shouldExpire(
            current: "Готово", expected: "Готово", operationRunning: false
        ))
        XCTAssertFalse(PreferencesFeedbackPolicy.shouldExpire(
            current: "Новый результат", expected: "Старый результат", operationRunning: false
        ))
    }

    func testRulesShowActuallyAppliedLimitWithoutAlteringDraft() {
        let draft = (1...52).map { "private-\($0)" }.joined(separator: "\n")
        let state = SensitiveRulesPresentation(text: draft)
        XCTAssertEqual(state.activeCount, SensitiveContentPolicy.normalizedRules(draft.components(separatedBy: .newlines)).count)
        XCTAssertEqual(state.activeCount, 50)
        XCTAssertEqual(state.ignoredUniqueCount, 2)
        XCTAssertEqual(state.overlongCount, 0)
        XCTAssertNotNil(state.warning)
        XCTAssertEqual(draft.components(separatedBy: .newlines).count, 52)
    }

    func testRuleWarningsDistinguishDuplicatesAndLongPhrases() {
        let repeated = Array(repeating: "secret\nSECRET\nsécret\n", count: 30).joined()
        let duplicates = SensitiveRulesPresentation(text: repeated)
        XCTAssertEqual(duplicates.activeCount, 1)
        XCTAssertEqual(duplicates.ignoredUniqueCount, 0)
        XCTAssertNil(duplicates.warning)
        let long = String(repeating: "🙂", count: 201)
        let bounded = SensitiveRulesPresentation(text: long)
        XCTAssertEqual(bounded.activeCount, 1)
        XCTAssertEqual(bounded.overlongCount, 1)
        XCTAssertNotNil(bounded.warning)
        XCTAssertEqual(long.count, 201)
    }

    func testEmptyRuleDraftHasNoActiveRulesOrWarning() {
        let state = SensitiveRulesPresentation(text: " \n\t\n")
        XCTAssertEqual(state.activeCount, 0)
        XCTAssertEqual(state.ignoredUniqueCount, 0)
        XCTAssertEqual(state.overlongCount, 0)
        XCTAssertNil(state.warning)
    }

    func testTerminalCanBeExcludedFromLayoutMemoryWithoutWeakeningTextProtection() {
        let identifier = "com.apple.Terminal"
        guard case .added(let excluded) = ApplicationExclusionPolicy.adding(identifier, to: []) else {
            return XCTFail("Terminal must be eligible for an explicit memory exclusion")
        }
        XCTAssertFalse(ApplicationLayoutMemoryPolicy.isEligible(
            bundleID: identifier, ownBundleID: "org.affpapa.neclip", userExcluded: Set(excluded)
        ))
        XCTAssertTrue(LayoutProtectedApplicationPolicy.blocksAutomatic(bundleID: identifier, userExcluded: []))
    }

    func testExclusionDuplicatesIgnoreCaseAndWhitespace() {
        XCTAssertEqual(ApplicationExclusionPolicy.adding(" COM.APPLE.TERMINAL ", to: ["com.apple.Terminal"]), .alreadyExcluded)
        XCTAssertEqual(ApplicationExclusionPolicy.adding(" \n", to: []), .invalidIdentifier)
        XCTAssertEqual(ApplicationExclusionPolicy.adding(" com.apple.Terminal ", to: []), .added(["com.apple.Terminal"]))
    }
}
