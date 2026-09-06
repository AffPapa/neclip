import XCTest
@testable import NeClip

final class SnippetsEditorPresentationTests: XCTestCase {
    func testRowContextKeepsFullUnicodeNamesForHelpAndAccessibility() {
        let keyword = String(repeating: "я", count: 100)
        let folder = String(repeating: "👩🏽‍💻", count: 200)
        XCTAssertEqual(
            SnippetRowContext.description(keyword: keyword, folder: folder),
            "\(keyword) · \(folder)"
        )
    }

    func testRowContextOmitsEmptyPartsWithoutDanglingSeparators() {
        XCTAssertEqual(SnippetRowContext.description(keyword: nil, folder: nil), "")
        XCTAssertEqual(SnippetRowContext.description(keyword: "", folder: "Без папки"), "Без папки")
        XCTAssertEqual(SnippetRowContext.description(keyword: ";thanks", folder: ""), ";thanks")
    }

    @MainActor
    func testSaveFailureRemainsExplainedAfterRefreshAndClearsAfterCorrection() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.addSnippet(folderID: nil, title: "Existing", content: "A", keyword: "taken")
        let id = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Editing", content: "B")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: id)
        model.editorKeyword = "taken"
        model.editorContent = "Retained draft"
        model.editorChanged()

        XCTAssertFalse(model.flushPendingSave())
        XCTAssertNotNil(model.editorMessage)
        XCTAssertEqual(try storage.fetchSnippet(id: id)?.content, "B")

        model.reload()
        XCTAssertEqual(model.selectedSnippetID, id)
        XCTAssertEqual(model.editorContent, "Retained draft")
        XCTAssertNotNil(model.editorMessage, "A refresh must not leave only an unexplained Retry button")

        model.editorKeyword = "available"
        model.editorChanged()
        XCTAssertNil(model.editorMessage)
        XCTAssertTrue(model.flushPendingSave())
        XCTAssertEqual(model.saveState, .saved)
        XCTAssertNil(model.editorMessage)
        XCTAssertEqual(try storage.fetchSnippet(id: id)?.content, "Retained draft")
        XCTAssertTrue(model.flushPendingSave(), "Saving an already-saved draft remains a harmless no-op")
    }
}
