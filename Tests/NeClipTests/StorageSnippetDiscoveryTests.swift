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

    func testExactKeywordWithoutSemicolonPrecedesNewerBodyMatchesBeforeLimit() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let exact = try XCTUnwrap(storage.addSnippet(
            folderID: nil, title: "Answer", content: "Ready", keyword: "hello"
        ))
        for index in 0..<25 {
            _ = try storage.addSnippet(folderID: nil, title: "hello \(index)", content: "hello body")
        }
        for query in ["hello", ";hello", "HELLO"] {
            XCTAssertEqual(try storage.snippetSummaries(search: query, limit: 1).first?.id, exact.id)
            XCTAssertEqual(try storage.allSnippets(search: query, limit: 1).first?.id, exact.id)
        }
    }

    func testFolderSearchFindsItsSnippetsInBothProjectionsAndTracksRename() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        var folder = try XCTUnwrap(storage.addFolder(title: "Быстрые ответы"))
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: folder.id, title: "Приветствие", content: "Здравствуйте!"
        ))
        _ = try storage.addSnippet(folderID: nil, title: "Другое", content: "Не подходит")
        XCTAssertEqual(try storage.snippetSummaries(search: "ОТВЕТЫ").map(\.id), [snippet.id])
        XCTAssertEqual(try storage.snippetSummaries(search: "ОТВЕТЫ").first?.folderTitle, "Быстрые ответы")
        XCTAssertEqual(try storage.allSnippets(search: "ОТВЕТЫ").map(\.id), [snippet.id])
        folder.title = "Письма"
        _ = try storage.update(folder)
        XCTAssertTrue(try storage.snippetSummaries(search: "ответы").isEmpty)
        XCTAssertEqual(try storage.snippetSummaries(search: "письма").first?.id, snippet.id)
    }

    func testFolderSearchTreatsPunctuationLiterallyAndUnionsWithoutDuplicates() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "100%_ ответы"))
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: folder.id, title: "ответы", content: "100%_ literal"
        ))
        _ = try storage.addSnippet(folderID: nil, title: "Other", content: "anything")
        XCTAssertEqual(try storage.snippetSummaries(search: "%_").map(\.id), [snippet.id])
        XCTAssertEqual(try storage.snippetSummaries(search: "ответы").map(\.id), [snippet.id])
        XCTAssertTrue(try storage.snippetSummaries(search: "' OR 1=1 --").isEmpty)
    }

    func testDuplicatePreservesContentFolderPinButNotKeywordOrUsage() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Work"))
        let original = try XCTUnwrap(storage.addSnippet(
            folderID: folder.id,
            title: String(repeating: "🙂", count: Storage.maximumSnippetTitleCharacters),
            content: "{date}\nExact content", keyword: "only-one"
        ))
        let id = try XCTUnwrap(original.id)
        try storage.setSnippetPinned(id: id, pinned: true)
        try storage.markSnippetUsed(id: id)
        let duplicate = try storage.duplicateSnippet(id: id)
        XCTAssertNotEqual(duplicate.id, id)
        XCTAssertEqual(duplicate.folderID, folder.id)
        XCTAssertEqual(duplicate.content, original.content)
        XCTAssertTrue(duplicate.isPinned)
        XCTAssertNil(duplicate.keyword)
        XCTAssertEqual(duplicate.useCount, 0)
        XCTAssertNil(duplicate.lastUsedAt)
        XCTAssertLessThanOrEqual(duplicate.title.count, Storage.maximumSnippetTitleCharacters)
        XCTAssertTrue(duplicate.title.hasSuffix(" — копия"))
        XCTAssertGreaterThan(duplicate.sortIndex, original.sortIndex)
        XCTAssertEqual(try storage.fetchSnippet(id: id)?.keyword, ";only-one")
    }

    func testMarkUsedNotifiesSnippetObserversAndChangesQuickOrder() async throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let first = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "First", content: "A")?.id)
        let second = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Second", content: "B")?.id)
        XCTAssertEqual(try storage.menuSnippetSnapshot().snippets.first?.id, second)
        // Drain notifications from setup before observing the usage mutation.
        await MainActor.run {}
        let changed = expectation(forNotification: .neClipStorageDidChange, object: storage) { notification in
            StorageChangeDomain.from(notification) == .snippets
        }
        try storage.markSnippetUsed(id: first)
        await fulfillment(of: [changed], timeout: 2)
        XCTAssertEqual(try storage.menuSnippetSnapshot().snippets.first?.id, first)
    }
}
