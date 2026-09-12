import Foundation
import XCTest
@testable import NeClip

final class ClipToSnippetTests: XCTestCase {
    func testConversionPreservesTextAndUsesFirstContentLineAndUnfiledOrder() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let existing = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Existing", content: "Other"))
        let title = String(repeating: "🐗", count: 70)
        let content = "  Полный текст\nсо строками и {clipboard}  "
        let rtf = Data([1, 2, 3])
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: title, text: content, rtf: rtf, createdAt: Date()
        )))
        let snippet = try storage.saveClipAsSnippet(id: id)
        XCTAssertEqual(snippet.title, "Полный текст")
        XCTAssertEqual(snippet.content, content)
        XCTAssertEqual(snippet.sortIndex, existing.sortIndex + 1)
        XCTAssertNil(snippet.folderID)
        XCTAssertEqual(try storage.fetchSnippet(id: XCTUnwrap(snippet.id))?.content, content)
        XCTAssertEqual(try storage.fetchClip(id: id)?.rtf, rtf)
        XCTAssertEqual(storage.count, 1)
    }

    func testConversionChoosesFolderAndSkipsExactDuplicateWithoutRenderingTokens() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Работа"))
        let content = "  Заголовок  \nТело {clipboard}"
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "ignored clipboard title", text: content, createdAt: Date()
        )))

        let first = try storage.saveClipAsSnippetResult(id: id, folderID: folder.id)
        guard case .created(let created) = first else { return XCTFail("First save must create") }
        XCTAssertEqual(created.title, "Заголовок")
        XCTAssertEqual(created.content, content)
        XCTAssertEqual(created.folderID, folder.id)

        let second = try storage.saveClipAsSnippetResult(id: id, folderID: folder.id)
        guard case .alreadyExists(let existing) = second else { return XCTFail("Second save must deduplicate") }
        XCTAssertEqual(existing.id, created.id)
        XCTAssertEqual(try storage.allSnippets().count, 1)
    }

    func testSameContentCanBeSavedInDifferentFolders() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let firstFolder = try XCTUnwrap(storage.addFolder(title: "A"))
        let secondFolder = try XCTUnwrap(storage.addFolder(title: "B"))
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Title", text: "same", createdAt: Date()
        )))
        _ = try storage.saveClipAsSnippetResult(id: id, folderID: firstFolder.id)
        let result = try storage.saveClipAsSnippetResult(id: id, folderID: secondFolder.id)
        guard case .created = result else { return XCTFail("Different folders may contain same content") }
        XCTAssertEqual(try storage.allSnippets().count, 2)
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
