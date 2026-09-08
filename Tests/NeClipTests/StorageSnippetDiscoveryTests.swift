import XCTest
@testable import NeClip

final class StorageSnippetDiscoveryTests: XCTestCase {
    func testSummaryBoundsUnicodePreviewWithoutCountingWholeBody() {
        let snippet = Snippet(folderID: nil, title: "Long", content: "👩🏽‍💻e\u{301}" + String(repeating: "x", count: 100_000))
        let summary = SnippetSummary(snippet: snippet, previewLimit: 2)
        XCTAssertEqual(summary.contentPreview, "👩🏽‍💻e\u{301}")
        XCTAssertTrue(summary.contentIsTruncated)
        XCTAssertEqual(SnippetSummary(snippet: snippet, previewLimit: -1).contentPreview, "")
        let short = Snippet(folderID: nil, title: "Short", content: "é")
        XCTAssertFalse(SnippetSummary(snippet: short, previewLimit: 1).contentIsTruncated)
    }

    func testDuplicatePreservesContentFolderPinButNotUsage() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Work"))
        let original = try XCTUnwrap(storage.addSnippet(
            folderID: folder.id,
            title: String(repeating: "🙂", count: Storage.maximumSnippetTitleCharacters),
            content: "{date}\nExact content"
        ))
        let id = try XCTUnwrap(original.id)
        try storage.setSnippetPinned(id: id, pinned: true)
        try storage.markSnippetUsed(id: id)
        let duplicate = try storage.duplicateSnippet(id: id)
        XCTAssertNotEqual(duplicate.id, id)
        XCTAssertEqual(duplicate.folderID, folder.id)
        XCTAssertEqual(duplicate.content, original.content)
        XCTAssertTrue(duplicate.isPinned)
        XCTAssertEqual(duplicate.useCount, 0)
        XCTAssertNil(duplicate.lastUsedAt)
        XCTAssertLessThanOrEqual(duplicate.title.count, Storage.maximumSnippetTitleCharacters)
        XCTAssertTrue(duplicate.title.hasSuffix(" — копия"))
        XCTAssertGreaterThan(duplicate.sortIndex, original.sortIndex)
    }

    func testLegacyUsageDoesNotReorderFolderMenu() async throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let first = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "First", content: "A")?.id)
        let second = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Second", content: "B")?.id)
        XCTAssertEqual(try storage.menuSnippetSnapshot().snippets.map(\.id), [first, second])
        // Drain notifications from setup before observing the usage mutation.
        await MainActor.run {}
        let changed = expectation(forNotification: .neClipStorageDidChange, object: storage) { notification in
            StorageChangeDomain.from(notification) == .snippets
        }
        try storage.markSnippetUsed(id: first)
        await fulfillment(of: [changed], timeout: 2)
        XCTAssertEqual(try storage.menuSnippetSnapshot().snippets.map(\.id), [first, second])
        XCTAssertEqual(try storage.menuSnippetSnapshot().recentSnippets.map(\.id), [first, second])
    }

    func testBoundedMenuUsesStableFolderOrderBeforeApplyingLimit() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Work"))
        let inFolder = try XCTUnwrap(storage.addSnippet(folderID: folder.id, title: "A", content: "A"))
        let unfiled = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "B", content: "B"))
        try storage.setSnippetPinned(id: XCTUnwrap(unfiled.id), pinned: true)
        try storage.markSnippetUsed(id: XCTUnwrap(unfiled.id))
        let snapshot = try storage.menuSnippetSnapshot(limit: 1)
        XCTAssertEqual(snapshot.snippets.map(\.id), [inFolder.id])
        XCTAssertEqual(snapshot.folders.map(\.id), [folder.id])
        XCTAssertTrue(snapshot.hasMore)
    }
}
