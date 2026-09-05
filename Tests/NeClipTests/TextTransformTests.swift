import XCTest
@testable import NeClip

final class TextTransformTests: XCTestCase {
    func testWhitespaceCaseAndLineTransforms() throws {
        XCTAssertEqual(try TextTransform.trim.apply(to: "  hi \n"), "hi")
        XCTAssertEqual(try TextTransform.collapseWhitespace.apply(to: " a \n\t b  "), "a b")
        XCTAssertEqual(try TextTransform.uppercase.apply(to: "Привет"), "ПРИВЕТ")
        XCTAssertEqual(try TextTransform.uniqueLines.apply(to: "b\na\nb"), "b\na")
        XCTAssertEqual(try TextTransform.sortLines.apply(to: "b\na"), "a\nb")
    }

    func testURLAndJSONTransformsRoundTrip() throws {
        let encoded = try TextTransform.urlEncode.apply(to: "hello world")
        XCTAssertEqual(try TextTransform.urlDecode.apply(to: encoded), "hello world")
        let pretty = try TextTransform.jsonPretty.apply(to: "{\"b\":2,\"a\":1}")
        XCTAssertTrue(pretty.contains("\n"))
        XCTAssertEqual(try TextTransform.jsonMinify.apply(to: pretty), "{\"a\":1,\"b\":2}")
    }

    func testInvalidJSONFailsWithoutChangingStoredContent() {
        XCTAssertThrowsError(try TextTransform.jsonPretty.apply(to: "not json"))
    }

    func testLineTransformsTreatCRLFAsOneSeparator() throws {
        XCTAssertEqual(try TextTransform.uniqueLines.apply(to: "b\r\na\r\nb"), "b\na")
        XCTAssertEqual(try TextTransform.sortLines.apply(to: "b\r\na"), "a\nb")
        XCTAssertEqual(try TextTransform.trimLines.apply(to: " a \r\n\r\n b\t\r\n"), "a\n\nb\n")
        XCTAssertEqual(try TextTransform.removeBlankLines.apply(to: " a \r\n \t\r\n\r\n b \r\n"), " a \n b ")
    }

    func testLineTransformsSupportUnicodeSeparatorsAndEmptyInput() throws {
        XCTAssertEqual(try TextTransform.trimLines.apply(to: " a \r b \u{2028} c \u{2029}"), "a\nb\nc\n")
        XCTAssertEqual(try TextTransform.removeBlankLines.apply(to: "\n\u{00A0}\n\t\n"), "")
        for transform in [TextTransform.trimLines, .removeBlankLines, .uniqueLines, .sortLines] {
            XCTAssertEqual(try transform.apply(to: ""), "")
        }
    }

    func testURLComponentEncodingEscapesAllReservedCharacters() throws {
        let reserved = ":/?#[]@!$&'()*+,;=%"
        let encoded = try TextTransform.urlEncode.apply(to: reserved)
        XCTAssertEqual(encoded, "%3A%2F%3F%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D%25")
        XCTAssertEqual(try TextTransform.urlDecode.apply(to: encoded), reserved)
        let unreserved = "AZaz09-._~"
        XCTAssertEqual(try TextTransform.urlEncode.apply(to: unreserved), unreserved)
    }

    func testURLComponentRoundTripPreservesUnicodeSpacesAndPlus() throws {
        for text in ["", "a=b&c+d", "Привет 👨‍👩‍👧‍👦\n", "a%20b", "one two", "e\u{301}"] {
            XCTAssertEqual(try TextTransform.urlDecode.apply(to: TextTransform.urlEncode.apply(to: text)), text)
        }
        XCTAssertEqual(try TextTransform.urlDecode.apply(to: "a+b"), "a+b")
        for malformed in ["%", "%2", "%GG", "%FF"] {
            XCTAssertThrowsError(try TextTransform.urlDecode.apply(to: malformed))
        }
    }
}
