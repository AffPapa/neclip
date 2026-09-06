import XCTest
@testable import NeClip

final class SnippetsEditorPresentationTests: XCTestCase {
    func testEditorHasNoSearchControlsOrDeferredSearchWork() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Sources/NeClip/SnippetsEditor.swift"), encoding: .utf8)
        for removed in ["@Published var query", "queryTask", "searchIsFocused", "scheduleQueryReload",
                        "noSearchResults", "showsFolder", "folderSubtitle", "SnippetRowContext",
                        "magnifyingglass", "editorKeyword", "Ключ поиска", "keyboardShortcut(\"f\""] {
            XCTAssertFalse(source.contains(removed), "Editor search must stay removed: \(removed)")
        }
    }

    @MainActor
    func testEditorAlwaysShowsFoldersAndUnfiledWithoutFiltering() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let firstFolder = try XCTUnwrap(storage.addFolder(title: "Первая"))
        let emptyFolder = try XCTUnwrap(storage.addFolder(title: "Пустая"))
        let firstID = try XCTUnwrap(firstFolder.id)
        let emptyID = try XCTUnwrap(emptyFolder.id)
        let first = try XCTUnwrap(storage.addSnippet(folderID: firstID, title: "Первый", content: "A"))
        let unfiled = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Без папки", content: "B"))
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        XCTAssertEqual(Set(model.folders.compactMap(\.id)), Set([firstID, emptyID]))
        XCTAssertEqual(model.snippets(in: firstID).map(\.id), [first.id])
        XCTAssertTrue(model.snippets(in: emptyID).isEmpty)
        XCTAssertEqual(model.snippets(in: nil).map(\.id), [unfiled.id])
        XCTAssertEqual(model.selectedSnippetID, first.id)
        XCTAssertTrue(model.openSnippet(id: try XCTUnwrap(unfiled.id)))
        XCTAssertEqual(model.snippets.count, 2, "Direct opening must not hide other snippets")
        XCTAssertEqual(model.selectedSnippetID, unfiled.id)
    }

    @MainActor
    func testSaveFailureRemainsExplainedAfterRefreshAndClearsAfterCorrection() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.addSnippet(folderID: nil, title: "Existing", content: "A")
        let id = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Editing", content: "B")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: id)
        model.editorTitle = String(repeating: "x", count: 201)
        model.editorContent = "Retained draft"
        model.editorChanged()

        XCTAssertFalse(model.flushPendingSave())
        XCTAssertNotNil(model.editorMessage)
        XCTAssertEqual(try storage.fetchSnippet(id: id)?.content, "B")

        model.reload()
        XCTAssertEqual(model.selectedSnippetID, id)
        XCTAssertEqual(model.editorContent, "Retained draft")
        XCTAssertNotNil(model.editorMessage, "A refresh must not leave only an unexplained Retry button")

        model.editorTitle = "Editing"
        model.editorChanged()
        XCTAssertNil(model.editorMessage)
        XCTAssertTrue(model.flushPendingSave())
        XCTAssertEqual(model.saveState, .saved)
        XCTAssertNil(model.editorMessage)
        XCTAssertEqual(try storage.fetchSnippet(id: id)?.content, "Retained draft")
        XCTAssertTrue(model.flushPendingSave(), "Saving an already-saved draft remains a harmless no-op")
    }
}
