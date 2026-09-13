import Foundation
import XCTest
@testable import NeClip

final class HistorySearchTests: XCTestCase {
    func testSearchMatchesTitleAndFullTextWithoutOCR() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let older = Date(timeIntervalSinceNow: -8 * 86_400)
        _ = try storage.insert(ClipItem(
            kind: .text, title: "Заявка", text: "Внутри есть уникальный маркер ЖУК-42",
            appBundleID: "com.example.editor", createdAt: older
        ))
        _ = try storage.insert(ClipItem(
            kind: .image, title: "Картинка", data: Data([1, 2, 3]),
            appBundleID: "com.example.editor", createdAt: Date()
        ))
        _ = try storage.insert(ClipItem(
            kind: .text, title: "Other", text: "ordinary",
            appBundleID: "com.example.mail", createdAt: Date()
        ))

        let textResults = try storage.searchClipSummaries(query: "жук-42")
        XCTAssertEqual(textResults.map(\.title), ["Заявка"])
        XCTAssertTrue(try storage.searchClipSummaries(query: "ЖУК-42", kind: .image).isEmpty)

        let editorResults = try storage.searchClipSummaries(query: "", appBundleID: "com.example.editor")
        XCTAssertEqual(editorResults.count, 2)
        let recent = try storage.searchClipSummaries(query: "", createdAfter: Date(timeIntervalSinceNow: -3_600))
        XCTAssertEqual(recent.count, 2)
    }

    func testSearchFiltersKindAndRespectsLimit() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        for index in 0..<5 {
            _ = try storage.insert(ClipItem(
                kind: .text, title: "same \(index)", text: "needle \(index)",
                createdAt: Date(timeIntervalSinceNow: TimeInterval(-index))
            ))
        }
        _ = try storage.insert(ClipItem(
            kind: .file, title: "needle file", text: "/tmp/needle.txt", createdAt: Date()
        ))
        XCTAssertEqual(try storage.searchClipSummaries(query: "needle", kind: .text, limit: 2).count, 2)
        XCTAssertEqual(try storage.searchClipSummaries(query: "needle", kind: .file).count, 1)
        XCTAssertEqual(try storage.searchClipSummaries(query: "").count, 6)
    }

    func testSearchDoesNotHideOlderMatchBehindRecentNonMatches() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let now = Date()
        for index in 0..<3 {
            _ = try storage.insert(ClipItem(
                kind: .text, title: "Recent \(index)", text: "unrelated",
                createdAt: now.addingTimeInterval(-TimeInterval(index))
            ))
        }
        _ = try storage.insert(ClipItem(
            kind: .text, title: "Older match", text: "needle",
            createdAt: now.addingTimeInterval(-100)
        ))

        let results = try storage.searchClipSummaries(query: "needle", limit: 1)
        XCTAssertEqual(results.map(\.title), ["Older match"])
    }

    func testFileClipboardCodecRoundTripsNewlinePathsAndReadsLegacyRows() {
        let urls = [URL(fileURLWithPath: "/tmp/name\nwith-newline.txt")]
        let encoded = FileClipboardCodec.encode(urls)
        XCTAssertNotNil(encoded)
        XCTAssertEqual(FileClipboardCodec.decode(encoded ?? "").map(\.path), urls.map(\.path))
        XCTAssertEqual(
            FileClipboardCodec.decode("/tmp/one.txt\n/tmp/two.txt").map(\.path),
            ["/tmp/one.txt", "/tmp/two.txt"]
        )
    }
}
