import XCTest
@testable import NeClip

final class SnippetTransferTests: XCTestCase {
    func testImportRejectsEmptyAndOversizedFilesBeforeDecoding() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)

        XCTAssertThrowsError(try storage.importSnippetData(Data())) { error in
            XCTAssertEqual(error as? SnippetTransferError, .fileTooLarge)
        }
        XCTAssertThrowsError(
            try storage.importSnippetData(
                Data(repeating: 0, count: Storage.maximumSnippetImportBytes + 1)
            )
        ) { error in
            XCTAssertEqual(error as? SnippetTransferError, .fileTooLarge)
        }
    }

    func testExportImportPreservesFoldersContentAndPinsWithoutUsageHistory() throws {
        let source = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(source.addFolder(title: "Ответы"))
        let snippet = try XCTUnwrap(source.addSnippet(
            folderID: folder.id,
            title: "Приветствие",
            content: "Здравствуйте, {clipboard}"
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

    func testExportRejectsLibraryThatItsOwnImporterCannotReadWithoutDeletingAnything() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let content = String(repeating: "x", count: ClipboardCapturePolicy.maxTextBytes)
        for index in 0..<9 {
            _ = try storage.addSnippet(folderID: nil, title: "Large \(index)", content: content)
        }
        XCTAssertThrowsError(try storage.exportSnippetData()) { error in
            XCTAssertEqual(error as? SnippetTransferError, .exportTooLarge)
        }
        XCTAssertEqual(try storage.snippetSummaries().count, 9)
    }
}
