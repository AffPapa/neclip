import XCTest
@testable import NeClip

final class SnippetsEditorTests: XCTestCase {
    @MainActor
    func testFailedSaveKeepsRetryStateAndDraftUntilSuccessfulRetry() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let occupied = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Occupied", content: "Other", keyword: "reserved")?.id)
        let edited = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Edited", content: "Original")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: edited)
        model.editorKeyword = "reserved"
        model.editorContent = "Draft to retry"
        model.editorChanged()
        XCTAssertFalse(model.flushPendingSave())
        guard case .failed = model.saveState else { return XCTFail("Failed save must retain its retry state") }
        XCTAssertEqual(model.message, SnippetStorageError.keywordAlreadyExists.errorDescription)
        XCTAssertEqual(model.editorContent, "Draft to retry")
        XCTAssertEqual(try storage.fetchSnippet(id: edited)?.content, "Original")

        try storage.deleteSnippet(id: occupied)
        XCTAssertTrue(model.flushPendingSave())
        XCTAssertEqual(model.saveState, .saved)
        XCTAssertNil(model.message)
        XCTAssertEqual(try storage.fetchSnippet(id: edited)?.content, "Draft to retry")
    }

    func testSnippetKeywordConflictsUseFriendlyTypedErrorAndPermitOwnKeyword() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let first = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "First", content: "Body", keyword: "Shared")?.id)
        XCTAssertThrowsError(try storage.addSnippet(folderID: nil, title: "Other", content: "Other", keyword: "SHARED")) {
            XCTAssertEqual($0 as? SnippetStorageError, .keywordAlreadyExists)
        }
        var same = try XCTUnwrap(storage.fetchSnippet(id: first))
        same.content = "Updated"
        XCTAssertEqual(try storage.update(same).content, "Updated")
        let second = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Second", content: "Other")?.id)
        var conflicting = try XCTUnwrap(storage.fetchSnippet(id: second))
        conflicting.keyword = "shared"
        XCTAssertThrowsError(try storage.update(conflicting)) {
            XCTAssertEqual($0 as? SnippetStorageError, .keywordAlreadyExists)
        }
        XCTAssertNil(try storage.fetchSnippet(id: second)?.keyword)
    }

    func testUnexpectedStorageErrorNeverDisplaysSQLOrPayload() {
        let rawError = NSError(domain: "SQLite", code: 19, userInfo: [
            NSLocalizedDescriptionKey: "UPDATE snippet SET content = 'private text'"
        ])
        XCTAssertEqual(
            SnippetStorageError.userFacingMessage(for: rawError, fallback: "Не удалось сохранить"),
            "Не удалось сохранить"
        )
    }

    @MainActor
    func testDeselectionDistinguishesExistingLibraryFromEmpty() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        XCTAssertEqual(model.emptyEditorState, .emptyLibrary)
        _ = try storage.addSnippet(folderID: nil, title: "Existing", content: "Body")
        model.reload()
        model.selectSnippet(nil)
        XCTAssertNil(model.selectedSnippetID)
        XCTAssertEqual(model.emptyEditorState, .chooseSnippet)
    }

    @MainActor
    func testFolderValidationAndRetryKeepSheetAndRenameContext() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Original"))
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.requestRename(folder)
        model.folderNameDraft = " \n\t "
        XCTAssertFalse(model.canSaveFolder)
        model.saveFolder()
        XCTAssertTrue(model.showFolderEditor)
        XCTAssertNotNil(model.folderEditorError)
        XCTAssertEqual(model.editingFolderID, folder.id)

        let tooLong = String(repeating: "a", count: Storage.maximumSnippetTitleCharacters + 1)
        model.folderNameDraft = tooLong
        model.saveFolder()
        XCTAssertTrue(model.showFolderEditor)
        XCTAssertEqual(model.folderNameDraft, tooLong)
        XCTAssertEqual(model.editingFolderID, folder.id)
        XCTAssertNotNil(model.folderEditorError)

        model.folderNameDraft = " Renamed "
        XCTAssertTrue(model.canSaveFolder)
        model.saveFolder()
        XCTAssertFalse(model.showFolderEditor)
        XCTAssertNil(model.folderEditorError)
        XCTAssertEqual(try storage.snippetFolders().first?.title, "Renamed")
    }

    @MainActor
    func testMissingFolderSavePreservesDraftUntilExplicitCancel() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Original"))
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.requestRename(folder)
        model.folderNameDraft = "Keep my name"
        try storage.deleteFolder(id: XCTUnwrap(folder.id))
        model.saveFolder()
        XCTAssertTrue(model.showFolderEditor)
        XCTAssertEqual(model.folderNameDraft, "Keep my name")
        XCTAssertEqual(model.editingFolderID, folder.id)
        XCTAssertNotNil(model.folderEditorError)
        model.cancelFolderEditing()
        XCTAssertFalse(model.showFolderEditor)
        XCTAssertEqual(model.folderNameDraft, "")
        XCTAssertNil(model.editingFolderID)
        XCTAssertNil(model.folderEditorError)
    }

    @MainActor
    func testCleanExternalChangeRefreshPreventsStalePinAndFolderOverwrite() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Destination"))
        let id = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Original", content: "Body")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        try storage.setSnippetPinned(id: id, pinned: true)
        _ = try storage.moveSnippet(id: id, toFolderID: folder.id)
        model.reload()
        XCTAssertTrue(model.editorPinned)
        XCTAssertEqual(model.editorFolderID, folder.id)
        model.editorTitle = "Edited title"
        model.editorChanged()
        XCTAssertTrue(model.flushPendingSave())
        let saved = try XCTUnwrap(storage.fetchSnippet(id: id))
        XCTAssertTrue(saved.isPinned)
        XCTAssertEqual(saved.folderID, folder.id)
    }

    @MainActor
    func testExternalRefreshKeepsDirtyTextAndSelection() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Original", content: "Body")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.editorContent = "Unsaved draft"
        model.editorChanged()
        try storage.setSnippetPinned(id: id, pinned: true)
        model.reload(reloadEditor: true)
        XCTAssertEqual(model.selectedSnippetID, id)
        XCTAssertEqual(model.editorContent, "Unsaved draft")
        XCTAssertEqual(model.saveState, .changed)
    }

    @MainActor
    func testDuplicateSavesDraftAndSelectsAnEditableCopy() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Original", content: "Body", keyword: "key")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.editorContent = "Newest draft"
        model.editorChanged()
        model.duplicateSelected()
        XCTAssertNotEqual(model.selectedSnippetID, id)
        XCTAssertEqual(model.editorContent, "Newest draft")
        XCTAssertEqual(model.editorKeyword, "")
        XCTAssertEqual(try storage.fetchSnippet(id: id)?.content, "Newest draft")
    }

    @MainActor
    func testDeleteUndoRestoresSelectionAndSurvivesDeletedFolder() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Temporary"))
        let folderID = try XCTUnwrap(folder.id)
        let id = try XCTUnwrap(storage.addSnippet(folderID: folderID, title: "Original", content: "Body")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.editorContent = "Latest edited body"
        model.editorChanged()
        model.deleteSelected()
        XCTAssertNil(try storage.fetchSnippet(id: id))
        XCTAssertNotNil(model.removedSnippet)
        try storage.deleteFolder(id: folderID)
        model.undoSnippetDeletion()
        XCTAssertEqual(model.selectedSnippetID, id)
        XCTAssertEqual(model.editorContent, "Latest edited body")
        XCTAssertNil(model.editorFolderID)
        XCTAssertNil(model.removedSnippet)
    }

    @MainActor
    func testFailedUndoRetainsRecoveryWhenKeywordIsOccupied() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Original", content: "Body", keyword: "key")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.deleteSelected()
        let other = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Other", content: "Other", keyword: "key")?.id)
        model.undoSnippetDeletion()
        XCTAssertNotNil(model.removedSnippet)
        XCTAssertNil(try storage.fetchSnippet(id: id))
        try storage.deleteSnippet(id: other)
        model.undoSnippetDeletion()
        XCTAssertEqual(model.selectedSnippetID, id)
        XCTAssertNil(model.removedSnippet)
    }

    @MainActor
    func testEraseAllDataDiscardsUndoPayload() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.addSnippet(folderID: nil, title: "Temporary", content: "Private text")
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.deleteSelected()
        XCTAssertNotNil(model.removedSnippet)
        model.createSnippet(in: nil)
        model.editorContent = "Draft that must be erased too"
        model.editorChanged()
        try storage.deleteAllUserData()
        model.storageDidChange(.all)
        XCTAssertNil(model.removedSnippet)
        XCTAssertNil(model.selectedSnippetID)
        XCTAssertEqual(model.editorContent, "")
        XCTAssertEqual(model.editorTitle, "")
        XCTAssertEqual(model.saveState, .idle)
        XCTAssertTrue(model.flushPendingSave())
        model.undoSnippetDeletion()
        XCTAssertTrue(try storage.allSnippets().isEmpty)
    }

    @MainActor
    func testFolderDeletionMessageCountsItsItems() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Folder"))
        _ = try storage.addSnippet(folderID: folder.id, title: "One", content: "A")
        _ = try storage.addSnippet(folderID: folder.id, title: "Two", content: "B")
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        XCTAssertEqual(model.snippets.count, 2)
        model.requestDelete(folder)
        XCTAssertTrue(model.folderDeletionMessage.contains("2 сниппета"))
        XCTAssertFalse(model.folderDeletionMessage.contains("пуста"))
    }

    @MainActor
    func testDirectOpenFlushesDraftAndSelectsRequestedID() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let first = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "First", content: "Body")?.id)
        let second = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Second", content: "Other")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: first)
        model.editorContent = "Saved before opening"
        model.editorChanged()
        XCTAssertTrue(model.openSnippet(id: second))
        XCTAssertEqual(model.selectedSnippetID, second)
        XCTAssertEqual(try storage.fetchSnippet(id: first)?.content, "Saved before opening")
    }

    @MainActor
    func testDirectOpenCannotDiscardInvalidDraft() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let first = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "First", content: "Body", keyword: "reserved")?.id)
        let second = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Second", content: "Other")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: second)
        model.editorKeyword = "reserved"
        model.editorChanged()
        XCTAssertFalse(model.openSnippet(id: first))
        XCTAssertEqual(model.selectedSnippetID, second)
        XCTAssertEqual(model.editorKeyword, "reserved")
    }
}
