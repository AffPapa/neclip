import Foundation
import XCTest
@testable import NeClip

final class ClipToSnippetTests: XCTestCase {
    func testConversionPreservesTextAndUsesCurrentTitleAndUnfiledOrder() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let existing = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Existing", content: "Other"))
        let title = String(repeating: "🐗", count: 70)
        let content = "  Полный текст\nсо строками и {clipboard}  "
        let rtf = Data([1, 2, 3])
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: title, text: content, rtf: rtf, createdAt: Date()
        )))
        let snippet = try storage.saveClipAsSnippet(id: id)
        XCTAssertEqual(snippet.title, String(title.prefix(60)))
        XCTAssertEqual(snippet.content, content)
        XCTAssertEqual(snippet.sortIndex, existing.sortIndex + 1)
        XCTAssertNil(snippet.folderID)
        XCTAssertEqual(try storage.fetchSnippet(id: XCTUnwrap(snippet.id))?.content, content)
        XCTAssertEqual(try storage.fetchClip(id: id)?.rtf, rtf)
        XCTAssertEqual(storage.count, 1)
    }

    func testMissingNonTextAndEmptyClipsDoNotCreateSnippets() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        XCTAssertThrowsError(try storage.saveClipAsSnippet(id: Int64.max)) {
            XCTAssertEqual($0 as? ClipStorageError, .clipNotFound)
        }
        for (index, fixture) in [
            (ClipKind.image, "Image OCR is not plain text" as String?),
            (.file, "File path"), (.text, nil), (.text, "")
        ].enumerated() {
            let id = try XCTUnwrap(storage.insert(ClipItem(
                kind: fixture.0, title: "Fixture \(index)", text: fixture.1,
                data: Data([UInt8(index)]), createdAt: Date()
            )))
            XCTAssertThrowsError(try storage.saveClipAsSnippet(id: id)) {
                XCTAssertEqual($0 as? ClipStorageError, .snippetRequiresText)
            }
        }
        XCTAssertTrue(try storage.allSnippets().isEmpty)
    }

    func testConversionRetainsSnippetContentSizeValidation() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Large", text: String(repeating: "a", count: ClipboardCapturePolicy.maxTextBytes + 1),
            createdAt: Date()
        )))
        XCTAssertThrowsError(try storage.saveClipAsSnippet(id: id)) {
            XCTAssertEqual($0 as? SnippetStorageError, .snippetContentTooLarge)
        }
        XCTAssertTrue(try storage.allSnippets().isEmpty)
    }

    func testQueuedConversionCannotRecreateContentAfterFullErasure() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Private", text: "Erased content", createdAt: Date()
        )))
        let queue = DispatchQueue(label: "test.clip-to-snippet.erasure")
        let release = DispatchSemaphore(value: 0)
        let finished = expectation(description: "queued conversion rejected")
        queue.async {
            guard release.wait(timeout: .now() + 5) == .success else {
                XCTFail("Test gate timed out"); finished.fulfill(); return
            }
            do {
                try storage.saveClipAsSnippet(id: id)
                XCTFail("Conversion queued before erasure must not recreate the erased text")
            } catch {
                XCTAssertEqual(error as? ClipStorageError, .clipNotFound)
            }
            finished.fulfill()
        }
        try storage.deleteAllUserData()
        // An intervening capture must not reuse the erased clip's identity.
        let freshID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Fresh", text: "Fresh content", createdAt: Date()
        )))
        XCTAssertNotEqual(freshID, id)
        release.signal()
        wait(for: [finished], timeout: 5)
        XCTAssertTrue(try storage.allSnippets().isEmpty)
        XCTAssertEqual(storage.count, 1)
    }

    func testConversionCompletedBeforeErasureIsErasedWithItsSource() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Private", text: "Erased content", createdAt: Date()
        )))
        try storage.saveClipAsSnippet(id: id)
        XCTAssertEqual(try storage.allSnippets().count, 1)
        try storage.deleteAllUserData()
        XCTAssertEqual(storage.count, 0)
        XCTAssertTrue(try storage.allSnippets().isEmpty)
    }
}
