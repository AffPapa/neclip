import AppKit
import XCTest
@testable import NeClip

final class HistoryInspectorTests: XCTestCase {
    @MainActor
    private func fixture() throws -> (Storage, ClipItem, HistoryItemInspectorSession) {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Original title", text: "Original body", createdAt: Date()
        )))
        let item = try XCTUnwrap(storage.fetchClip(id: id))
        let session = HistoryItemInspectorSession(storage: storage)
        XCTAssertTrue(session.accept(item, request: session.beginRequest()))
        return (storage, item, session)
    }

    @MainActor
    func testDirtyDraftRequiresExplicitSaveDiscardOrCancel() throws {
        let (storage, item, session) = try fixture()
        let model = try XCTUnwrap(session.model)
        XCTAssertFalse(model.isDirty)
        XCTAssertTrue(session.prepareToLeave { XCTFail("Clean item should not prompt"); return .cancel })
        model.title = "New title"
        model.text = "New body"
        XCTAssertTrue(model.isDirty)
        XCTAssertFalse(session.prepareToLeave { .cancel })
        XCTAssertEqual(model.text, "New body")
        XCTAssertEqual(try storage.fetchClip(id: item.id!)?.text, "Original body")
        XCTAssertTrue(session.prepareToLeave { .discard })
        XCTAssertEqual(try storage.fetchClip(id: item.id!)?.text, "Original body")
        // A later termination guard may veto quitting. Choosing discard must
        // not eagerly clear the still-visible draft before the operation wins.
        XCTAssertTrue(model.isDirty)
        XCTAssertTrue(session.prepareToLeave { .save })
        XCTAssertFalse(model.isDirty)
        XCTAssertEqual(try storage.fetchClip(id: item.id!)?.title, "New title")
        XCTAssertEqual(try storage.fetchClip(id: item.id!)?.text, "New body")
    }

    @MainActor
    func testFailedSaveVetoesLeavingAndKeepsDraftForRetry() throws {
        let (storage, item, session) = try fixture()
        let model = try XCTUnwrap(session.model)
        model.title = "Unsaved title"
        model.text = "  "
        XCTAssertFalse(session.prepareToLeave { .save })
        XCTAssertTrue(model.isDirty)
        XCTAssertEqual(model.title, "Unsaved title")
        XCTAssertEqual(model.text, "  ")
        XCTAssertEqual(model.feedback, ClipStorageError.emptyText.errorDescription)
        XCTAssertEqual(try storage.fetchClip(id: item.id!)?.title, "Original title")
        model.text = "Valid retry"
        XCTAssertTrue(model.save())
        XCTAssertFalse(model.isDirty)
        XCTAssertEqual(try storage.fetchClip(id: item.id!)?.text, "Valid retry")
    }

    @MainActor
    func testDeletingStoredItemNeverReinsertsInspectorDraft() throws {
        let (storage, item, session) = try fixture()
        let model = try XCTUnwrap(session.model)
        model.text = "Draft"
        _ = try storage.removeClip(id: item.id!)
        XCTAssertFalse(session.prepareToLeave { .save })
        XCTAssertTrue(model.isDirty)
        XCTAssertEqual(model.feedback, ClipStorageError.clipNotFound.errorDescription)
        XCTAssertNil(try storage.fetchClip(id: item.id!))
    }

    @MainActor
    func testLatestRequestWinsAndClosedRequestsCannotReopen() throws {
        let (_, item, session) = try fixture()
        let stale = session.beginRequest()
        let current = session.beginRequest()
        XCTAssertFalse(session.accept(item, request: stale))
        XCTAssertTrue(session.accept(item, request: current))
        session.invalidateRequests()
        XCTAssertFalse(session.isCurrent(current))
        XCTAssertFalse(session.accept(item, request: current))
    }

    @MainActor
    func testFullEraseDropsRetainedDraftAndRejectsPendingPayload() throws {
        let (storage, item, session) = try fixture()
        var previewedItem = item
        previewedItem.ocrText = "Private OCR text"
        XCTAssertTrue(session.accept(previewedItem, request: session.beginRequest()))
        let retainedModel = try XCTUnwrap(session.model)
        XCTAssertEqual(retainedModel.ocrText, "Private OCR text")
        retainedModel.title = "Private title"
        retainedModel.text = "Private draft"
        let pending = session.beginRequest()
        try storage.deleteAllUserData()
        session.invalidate()
        XCTAssertNil(session.model)
        XCTAssertEqual(retainedModel.title, "")
        XCTAssertEqual(retainedModel.text, "")
        XCTAssertNil(retainedModel.imagePreview)
        XCTAssertNil(retainedModel.ocrText)
        XCTAssertFalse(retainedModel.isDirty)
        XCTAssertFalse(retainedModel.canOpen)
        XCTAssertFalse(retainedModel.save())
        XCTAssertFalse(session.accept(item, request: pending))
        XCTAssertNil(session.model)
        XCTAssertNil(try storage.fetchClip(id: item.id!))
    }

    @MainActor
    func testReturningToOriginalTextClearsDirtyState() throws {
        let (_, _, session) = try fixture()
        let model = try XCTUnwrap(session.model)
        model.text = "Temporary edit"
        XCTAssertTrue(model.isDirty)
        model.text = "Original body"
        XCTAssertFalse(model.isDirty)
    }

    @MainActor
    func testSavedSizeAndFeedbackFollowSubsequentEdits() throws {
        let (storage, item, session) = try fixture()
        let model = try XCTUnwrap(session.model)
        model.text = "Другой размер текста"
        XCTAssertTrue(model.save())
        XCTAssertEqual(model.feedback, "Сохранено")
        XCTAssertEqual(model.contentBytes, Int64(model.text.utf8.count))
        XCTAssertEqual(model.contentBytes, try storage.fetchClip(id: item.id!)?.contentBytes)
        model.text += "!"
        XCTAssertTrue(model.isDirty)
        XCTAssertNil(model.feedback)
        XCTAssertTrue(model.save())
        XCTAssertEqual(model.feedback, "Сохранено")
        model.title = "Updated title"
        XCTAssertTrue(model.isDirty)
        XCTAssertNil(model.feedback)
    }

    @MainActor
    func testApplicationMenuMakesSettingsAndNativeAboutDiscoverable() {
        let target = NSObject()
        let menu = AppDelegate.makeApplicationMenu(target: target)
        let items = menu.items.filter { !$0.isSeparatorItem }
        XCTAssertEqual(items.map(\.title), ["О NeClip", "Настройки…", "Выйти из NeClip"])
        XCTAssertEqual(items.map(\.keyEquivalent), ["", ",", "q"])
        XCTAssertEqual(items.map { $0.action.map(NSStringFromSelector) }, [
            "showAboutFromApplicationMenu", "openSettingsFromApplicationMenu", "quitFromApplicationMenu"
        ])
        for item in items {
            XCTAssertTrue(item.target === target)
            XCTAssertEqual(item.keyEquivalentModifierMask, [.command])
        }
    }

    @MainActor
    func testNativeEditCommandsUseFocusedResponderAndStandardShortcuts() {
        let menu = AppDelegate.makeEditMenu()
        XCTAssertEqual(menu.title, "Правка")
        XCTAssertTrue(menu.autoenablesItems)
        let items = menu.items.filter { !$0.isSeparatorItem }
        XCTAssertEqual(items.map(\.title), ["Отменить", "Повторить", "Вырезать", "Копировать", "Вставить", "Выбрать всё"])
        XCTAssertEqual(items.map { $0.action.map(NSStringFromSelector) }, ["undo:", "redo:", "cut:", "copy:", "paste:", "selectAll:"])
        XCTAssertEqual(items.map(\.keyEquivalent), ["z", "z", "x", "c", "v", "a"])
        for (index, item) in items.enumerated() {
            XCTAssertNil(item.target)
            XCTAssertEqual(item.keyEquivalentModifierMask, index == 1 ? [.command, .shift] : [.command])
        }
    }
}
