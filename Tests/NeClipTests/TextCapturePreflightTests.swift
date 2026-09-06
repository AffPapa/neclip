import Foundation
import XCTest
@testable import NeClip

final class TextCapturePreflightTests: XCTestCase {
    func testExactUTF8BoundaryRetainsWholeMultibyteText() {
        let text = "éЖ🐗"
        XCTAssertEqual(text.utf8.count, 8)
        XCTAssertNil(ClipboardCapturePolicy.textRejectionReason(
            text, userLimit: 8, sensitiveRules: []
        ))
        XCTAssertEqual(ClipboardCapturePolicy.textRejectionReason(
            text, userLimit: 7, sensitiveRules: []
        ), .tooLarge)
    }

    func testOversizeRejectionPrecedesUnicodeNormalization() {
        let text = String(repeating: "СЕКРЕТ é", count: 512)
        XCTAssertEqual(ClipboardCapturePolicy.textRejectionReason(
            text, userLimit: 64, sensitiveRules: ["секрет"]
        ), .tooLarge)
        XCTAssertEqual(ClipboardCapturePolicy.textRejectionReason(
            String(repeating: " ", count: 128), userLimit: 64, sensitiveRules: []
        ), .tooLarge)
    }

    func testAcceptedSizePreservesEmptyAndSensitiveDecisions() {
        for text in ["", " \t\r\n"] {
            XCTAssertEqual(ClipboardCapturePolicy.textRejectionReason(
                text, userLimit: 64, sensitiveRules: []
            ), .empty)
        }
        XCTAssertEqual(ClipboardCapturePolicy.textRejectionReason(
            "СЕКРЕТ CAFÉ", userLimit: 64, sensitiveRules: ["секрет cafe"]
        ), .sensitiveContent)
        XCTAssertNil(ClipboardCapturePolicy.textRejectionReason(
            "Обычная заметка", userLimit: 64, sensitiveRules: ["секрет"]
        ))
    }

    func testEmptyRulesAcceptLargeUnicodeTextWithoutChangingMatchingSemantics() {
        let text = String(repeating: "éЖ🐗", count: 262_144)
        XCTAssertFalse(SensitiveContentPolicy.matches(text, normalizedRules: []))
        XCTAssertFalse(SensitiveContentPolicy.matches(text, rules: ["", " \n"]))
        XCTAssertTrue(SensitiveContentPolicy.matches("Résumé СЕКРЕТ", normalizedRules: ["resume"]))
        XCTAssertTrue(SensitiveContentPolicy.matches("Résumé СЕКРЕТ", normalizedRules: ["секрет"]))
    }
}
