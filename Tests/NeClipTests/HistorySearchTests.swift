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
}
