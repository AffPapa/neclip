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
}
