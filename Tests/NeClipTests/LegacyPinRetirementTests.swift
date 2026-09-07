import XCTest
@testable import NeClip

final class LegacyPinRetirementTests: XCTestCase {
    func testUnpinPreservesEveryPayloadAndOnlyChangesChosenRecord() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let payload = Data([1, 2, 3, 4])
        let id = try XCTUnwrap(storage.insert(ClipItem(kind: .image, title: "Old image", data: payload, createdAt: Date())))
        let other = try XCTUnwrap(storage.insert(ClipItem(kind: .text, title: "Other", text: "Keep", createdAt: Date())))
        try storage.setPinned(id: id, pinned: true)
        try storage.setPinned(id: other, pinned: true)
        XCTAssertTrue(try storage.unpinLegacyClip(id: id))
        let item = try XCTUnwrap(storage.fetchClip(id: id))
        XCTAssertEqual(item.data, payload)
        XCTAssertFalse(item.isPinned)
        XCTAssertNil(item.pinnedAt)
        XCTAssertTrue(try XCTUnwrap(storage.fetchClip(id: other)).isPinned)
        XCTAssertFalse(try storage.unpinLegacyClip(id: id))
        XCTAssertFalse(try storage.unpinLegacyClip(id: -1))
    }

    @MainActor
    func testDraftToSnippetDoesNotTrimOrModifyUnpinnedOriginal() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.insert(ClipItem(kind: .text, title: "Original", text: "Original body", createdAt: Date())))
        try storage.setPinned(id: id, pinned: true)
        let model = HistoryItemInspectorModel(item: try XCTUnwrap(storage.fetchClip(id: id)), imagePreviewData: nil, storage: storage)
        model.unpinLegacyItem()
        model.title = "Draft"
        model.text = "New body"
        model.saveAsSnippet()
        let summary = try XCTUnwrap(storage.snippetSummaries().first)
        let snippet = try XCTUnwrap(storage.fetchSnippet(id: XCTUnwrap(summary.id)))
        XCTAssertEqual(snippet.content, "New body")
        XCTAssertEqual(snippet.title, "Draft")
        XCTAssertEqual(try storage.fetchClip(id: id)?.text, "Original body")
        XCTAssertTrue(model.isDirty)
    }

    @MainActor
    func testInvalidatedInspectorCannotUnpinOrCreateSnippet() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.insert(ClipItem(kind: .text, title: "Saved", text: "Body", createdAt: Date())))
        try storage.setPinned(id: id, pinned: true)
        let model = HistoryItemInspectorModel(item: try XCTUnwrap(storage.fetchClip(id: id)), imagePreviewData: nil, storage: storage)
        model.invalidate()
        model.unpinLegacyItem()
        model.saveAsSnippet()
        XCTAssertTrue(try XCTUnwrap(storage.fetchClip(id: id)).isPinned)
        XCTAssertTrue(try storage.snippetSummaries().isEmpty)
    }
}
