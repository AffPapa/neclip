import XCTest
@testable import NeClip

final class SnippetTransferTests: XCTestCase {
    func testExportImportPreservesFoldersContentAndPinsWithoutUsageHistory() throws {
        let source = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(source.addFolder(title: "Ответы"))
        let snippet = try XCTUnwrap(source.addSnippet(
            folderID: folder.id,
            title: "Приветствие",
            content: "Здравствуйте, {clipboard}",
            keyword: ";hello"
        ))
        try source.setSnippetPinned(id: XCTUnwrap(snippet.id), pinned: true)
        try source.markSnippetUsed(id: XCTUnwrap(snippet.id))

        let data = try source.exportSnippetData()
        let target = try Storage(inMemory: true, installStarterContent: false)
        XCTAssertEqual(try target.importSnippetData(data), 1)
        XCTAssertEqual(try target.importSnippetData(data), 0)

        let imported = try XCTUnwrap(target.allSnippets().first)
        XCTAssertEqual(imported.title, "Приветствие")
        XCTAssertEqual(imported.content, "Здравствуйте, {clipboard}")
        XCTAssertEqual(imported.keyword, ";hello")
        XCTAssertTrue(imported.isPinned)
        XCTAssertEqual(imported.useCount, 0)
        XCTAssertEqual(try target.snippetFolders().map(\.title), ["Ответы"])
    }

    func testUnsupportedVersionIsRejectedBeforeMutation() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let document = SnippetTransferDocument(version: 999, snippets: [])
        let data = try JSONEncoder().encode(document)
        XCTAssertThrowsError(try storage.importSnippetData(data)) { error in
            XCTAssertEqual(error as? SnippetTransferError, .unsupportedVersion)
        }
        XCTAssertTrue(try storage.allSnippets().isEmpty)
    }
}
