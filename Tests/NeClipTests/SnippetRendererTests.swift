import XCTest
@testable import NeClip

final class SnippetRenderingBehaviorTests: XCTestCase {
    func testLiteralUnknownAndIncompleteTokensArePreserved() throws {
        for text in ["", "Привет 👨‍👩‍👧‍👦", "{unknown}", "{date", "x{", "{DATE}", "{{unknown}}"] {
            XCTAssertEqual(try SnippetRenderer.render(text), text)
        }
    }

    func testAllKnownTokensCanBeEscapedWithoutClipboardAccess() throws {
        let text = "{{date}} {{time}} {{clipboard}} {{date:iso}} {{time:iso}}"
        XCTAssertEqual(
            try SnippetRenderer.render(text),
            "{date} {time} {clipboard} {date:iso} {time:iso}"
        )
    }

    func testInsertedClipboardIsLiteralAndRepeatedTokensAreStable() throws {
        let payload = "{date:iso} {time} {{clipboard}} 👩🏽‍💻"
        XCTAssertEqual(
            try SnippetRenderer.render("{clipboard}\n{clipboard}", clipboard: payload),
            payload + "\n" + payload
        )
        XCTAssertEqual(try SnippetRenderer.render("x{clipboard}y"), "xy")
    }

    func testISOUsesExplicitTimeZoneAndGregorianCalendarRegardlessOfLocale() throws {
        let date = Date(timeIntervalSince1970: 86_399)
        let template = "{date:iso}T{time:iso} / {date:iso}"
        XCTAssertEqual(
            try SnippetRenderer.render(template, date: date, locale: Locale(identifier: "th_TH"), timeZone: TimeZone(secondsFromGMT: 0)!),
            "1970-01-01T23:59:59 / 1970-01-01"
        )
        XCTAssertEqual(
            try SnippetRenderer.render(template, date: date, locale: Locale(identifier: "ar_SA"), timeZone: TimeZone(secondsFromGMT: 3_600)!),
            "1970-01-02T00:59:59 / 1970-01-02"
        )
    }

    func testAdjacentTokensAndEscapesDoNotConsumeSurroundingUnicode() throws {
        XCTAssertEqual(
            try SnippetRenderer.render("Я{{clipboard}}{clipboard}末", clipboard: "🙂"),
            "Я{clipboard}🙂末"
        )
        XCTAssertEqual(
            try SnippetRenderer.render("{clipboard}\u{301}", clipboard: "e"),
            "e\u{301}"
        )
    }

    func testLargeLiteralTemplateAndBraceHeavyTextRemainUnchanged() throws {
        let literal = String(repeating: "а", count: 100_000)
        XCTAssertEqual(try SnippetRenderer.render(literal), literal)
        let braces = String(repeating: "{x}", count: 20_000)
        XCTAssertEqual(try SnippetRenderer.render(braces), braces)
    }

    func testAmplifiedClipboardFailsBeforeExceedingOutputLimit() throws {
        XCTAssertThrowsError(try SnippetRenderer.render("{clipboard}{clipboard}", clipboard: "12345", maxOutputBytes: 9)) {
            XCTAssertEqual($0 as? SnippetRenderingError, .outputTooLarge(maximumBytes: 9))
        }
        XCTAssertEqual(try SnippetRenderer.render("{clipboard}{clipboard}", clipboard: "12345", maxOutputBytes: 10), "1234512345")
    }

    func testOutputLimitUsesUTF8BytesAndNeverTruncates() throws {
        XCTAssertThrowsError(try SnippetRenderer.render("🙂", maxOutputBytes: 3))
        XCTAssertEqual(try SnippetRenderer.render("🙂", maxOutputBytes: 4), "🙂")
        XCTAssertThrowsError(try SnippetRenderer.render("🙂{clipboard}", clipboard: "a", maxOutputBytes: 4))
        XCTAssertEqual(try SnippetRenderer.render("", maxOutputBytes: 0), "")
        XCTAssertEqual(try SnippetRenderer.render("{clipboard}", maxOutputBytes: 0), "")
    }
}
