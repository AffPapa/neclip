import Foundation
import GRDB
import XCTest
@testable import NeClip

final class StorageTests: XCTestCase {
    private var previousHistoryLimit = Settings.historyLimit

    override func setUp() {
        super.setUp()
        previousHistoryLimit = Settings.historyLimit
        Settings.historyLimit = 100
    }

    override func tearDown() {
        Settings.historyLimit = previousHistoryLimit
        super.tearDown()
    }

    func testSummaryPreservesRUENAndDigitsWithoutOriginalBlob() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let payload = Data(repeating: 7, count: 128 * 1024)
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "Счёт 2026",
            text: "Привет from NeClip 2026",
            data: payload,
            appBundleID: "com.apple.TextEdit",
            createdAt: Date()
        )))


        _ = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "literal %_ marker",
            text: "percent and underscore",
            createdAt: Date().addingTimeInterval(1)
        )))

        let summary = try XCTUnwrap(storage.summaries().first { $0.id == id })
        XCTAssertEqual(summary.text, "Привет from NeClip 2026")
        let full = try XCTUnwrap(storage.fetchClip(id: id))
        XCTAssertEqual(full.data, payload)
    }

    func testHashDedupKeepsOneRowAndMovesItToNewestSource() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let firstDate = Date(timeIntervalSince1970: 10)
        let secondDate = Date(timeIntervalSince1970: 20)
        let firstID = try storage.insert(ClipItem(
            kind: .text,
            title: "same",
            text: "same payload",
            appBundleID: "app.one",
            createdAt: firstDate
        ))
        let secondID = try storage.insert(ClipItem(
            kind: .text,
            title: "same",
            text: "same payload",
            appBundleID: "app.two",
            createdAt: secondDate
        ))

        XCTAssertEqual(firstID, secondID)
        XCTAssertEqual(storage.count, 1)
        let item = try XCTUnwrap(storage.fetchClip(id: XCTUnwrap(firstID)))
        XCTAssertEqual(item.appBundleID, "app.two")
        XCTAssertEqual(item.createdAt, secondDate)
    }

    func testHashDedupDropsStaleRTFWhenLatestCopyIsPlainText() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "rich",
            text: "same payload",
            rtf: Data([1, 2, 3]),
            createdAt: Date(timeIntervalSince1970: 10)
        )))

        XCTAssertEqual(try storage.fetchClip(id: id)?.rtf, Data([1, 2, 3]))
        XCTAssertEqual(try storage.insert(ClipItem(
            kind: .text,
            title: "plain",
            text: "same payload",
            rtf: nil,
            createdAt: Date(timeIntervalSince1970: 20)
        )), id)

        XCTAssertNil(try storage.fetchClip(id: id)?.rtf)
    }

    func testSequentialPasteIDsUsePhysicalRecencyInsteadOfPinOrder() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let oldest = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "oldest",
            text: "oldest",
            createdAt: Date(timeIntervalSince1970: 10)
        )))
        try storage.setPinned(id: oldest, pinned: true)
        let newest = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "newest",
            text: "newest",
            createdAt: Date(timeIntervalSince1970: 30)
        )))
        let middle = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "middle",
            text: "middle",
            createdAt: Date(timeIntervalSince1970: 20)
        )))

        XCTAssertEqual(try storage.recentClipIDs(), [newest, middle, oldest])
        XCTAssertEqual(try storage.recentClipIDs(limit: 2), [newest, middle])
    }

    func testModernRowsNeverFallBackToFullPayloadComparison() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let firstID = try storage.insert(ClipItem(
            kind: .text,
            title: "first",
            text: "same payload with distinct authoritative hashes",
            createdAt: Date(timeIntervalSince1970: 10),
            contentHash: String(repeating: "a", count: 64)
        ))
        let secondID = try storage.insert(ClipItem(
            kind: .text,
            title: "second",
            text: "same payload with distinct authoritative hashes",
            createdAt: Date(timeIntervalSince1970: 20),
            contentHash: String(repeating: "b", count: 64)
        ))

        XCTAssertNotEqual(firstID, secondID)
        XCTAssertEqual(storage.count, 2)
    }

    func testUnusedLegacyThumbnailsAreRemovedWithoutTouchingOriginalImages() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("neclip-thumbnail-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("fixture.sqlite").path
        let original = Data([1, 2, 3, 4])
        let derivedThumbnail = Data(repeating: 9, count: 128)

        var initial: Storage? = try Storage(path: path, installStarterContent: false)
        let id = try XCTUnwrap(initial?.insert(ClipItem(
            kind: .image,
            title: "image",
            data: original,
            createdAt: Date()
        )))
        initial = nil

        try DatabaseQueue(path: path).write { db in
            try db.execute(
                sql: "UPDATE clip SET thumbnail = ?, contentBytes = ? WHERE id = ?",
                arguments: [derivedThumbnail, original.count + derivedThumbnail.count, id]
            )
            try db.execute(
                sql: "DELETE FROM grdb_migrations WHERE identifier = 'v5-remove-unused-thumbnails'"
            )
        }

        let migrated = try Storage(path: path, installStarterContent: false)
        let item = try XCTUnwrap(migrated.fetchClip(id: id))
        XCTAssertEqual(item.data, original)
        XCTAssertEqual(item.contentBytes, Int64(original.count))
        XCTAssertNil(try DatabaseQueue(path: path).read { db in
            try Data.fetchOne(db, sql: "SELECT thumbnail FROM clip WHERE id = ?", arguments: [id])
        })
    }

    func testPinSurvivesTrimAndClearThenUndoRestoresPayload() throws {
        Settings.historyLimit = 10
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let pinnedID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "keep",
            text: "pinned sentinel",
            createdAt: Date(timeIntervalSince1970: 1)
        )))
        try storage.setPinned(id: pinnedID, pinned: true)

        for index in 0..<14 {
            _ = try storage.insert(ClipItem(
                kind: .text,
                title: "item \(index)",
                text: "unique \(index)",
                createdAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
            ))
        }

        XCTAssertEqual(storage.count, 11)
        XCTAssertNotNil(try storage.fetchClip(id: pinnedID))
        try storage.clearHistory(includePinned: false)
        XCTAssertEqual(storage.count, 1)

        let removed = try XCTUnwrap(storage.removeClip(id: pinnedID))
        XCTAssertEqual(storage.count, 0)
        try storage.restoreClip(removed)
        XCTAssertEqual(try storage.fetchClip(id: pinnedID)?.text, "pinned sentinel")
        XCTAssertEqual(try storage.fetchClip(id: pinnedID)?.isPinned, true)
    }

    func testPinnedHardCapRejectsNewCaptureInsteadOfGrowingForever() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let pinnedID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "capacity sentinel",
            text: "small payload with accounted quota",
            createdAt: Date(),
            contentBytes: Storage.maximumStorageBytes
        )))
        try storage.setPinned(id: pinnedID, pinned: true)

        XCTAssertThrowsError(try storage.insert(ClipItem(
            kind: .text,
            title: "must be rejected",
            text: "new payload",
            createdAt: Date().addingTimeInterval(1),
            contentBytes: 1
        ))) { error in
            XCTAssertEqual(error as? StorageCapacityError, .pinnedItemsUseAllAvailableSpace)
        }
        XCTAssertEqual(storage.count, 1)
    }

    func testAppendNextTextUpdatesOneRecordAndDropsIncompatibleRTF() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let firstID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "alpha",
            text: "alpha",
            rtf: Data([1, 2, 3]),
            appBundleID: "app.one",
            createdAt: Date(timeIntervalSince1970: 10)
        )))

        let result = try storage.appendToLatestUnpinnedText(
            "beta",
            appBundleID: "app.two",
            createdAt: Date(timeIntervalSince1970: 20),
            maximumBytes: 1_024
        )

        XCTAssertEqual(result, .appended(firstID))
        XCTAssertEqual(storage.count, 1)
        let merged = try XCTUnwrap(storage.fetchClip(id: firstID))
        XCTAssertEqual(merged.text, "alpha\nbeta")
        XCTAssertEqual(merged.title, "alpha beta")
        XCTAssertNil(merged.rtf)
        XCTAssertEqual(merged.appBundleID, "app.two")
        XCTAssertEqual(merged.createdAt, Date(timeIntervalSince1970: 20))
        XCTAssertEqual(merged.contentBytes, Int64("alpha\nbeta".utf8.count))
        XCTAssertNotNil(merged.contentHash)
    }

    func testAppendNextTextFallsBackWithoutMutatingWhenCombinedValueIsTooLarge() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let firstID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "alpha",
            text: "alpha",
            createdAt: Date(timeIntervalSince1970: 10)
        )))

        XCTAssertEqual(try storage.appendToLatestUnpinnedText(
            "beta",
            appBundleID: "app.two",
            createdAt: Date(timeIntervalSince1970: 20),
            maximumBytes: 5
        ), .combinedValueTooLarge)
        XCTAssertEqual(try storage.fetchClip(id: firstID)?.text, "alpha")
    }

    func testAppendNextTextReusesExistingDuplicateInsteadOfCreatingTwoRows() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.insert(ClipItem(
            kind: .text,
            title: "alpha",
            text: "alpha",
            createdAt: Date(timeIntervalSince1970: 20)
        ))
        let duplicateID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "combined",
            text: "alpha\nbeta",
            createdAt: Date(timeIntervalSince1970: 10)
        )))
        // Make the short value newest so append chooses it.
        _ = try storage.insert(ClipItem(
            kind: .text,
            title: "alpha",
            text: "alpha",
            createdAt: Date(timeIntervalSince1970: 30)
        ))

        XCTAssertEqual(try storage.appendToLatestUnpinnedText(
            "beta",
            appBundleID: "app.two",
            createdAt: Date(timeIntervalSince1970: 40),
            maximumBytes: 1_024
        ), .appended(duplicateID))
        XCTAssertEqual(storage.count, 1)
        XCTAssertEqual(try storage.fetchClip(id: duplicateID)?.text, "alpha\nbeta")
    }

    func testByteQuotaTrimDeletesTheSmallestOldestPrefixInOnePass() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let oldestID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "oldest",
            text: "oldest",
            createdAt: Date(timeIntervalSince1970: 10),
            contentBytes: 100 * 1024 * 1024
        )))
        let middleID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "middle",
            text: "middle",
            createdAt: Date(timeIntervalSince1970: 20),
            contentBytes: 100 * 1024 * 1024
        )))
        let newestID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "newest",
            text: "newest",
            createdAt: Date(timeIntervalSince1970: 30),
            contentBytes: 60 * 1024 * 1024
        )))

        XCTAssertNil(try storage.fetchClip(id: oldestID))
        XCTAssertNotNil(try storage.fetchClip(id: middleID))
        XCTAssertNotNil(try storage.fetchClip(id: newestID))
        XCTAssertEqual(storage.count, 2)
    }

    func testOCRTextIsCountedAgainstPinnedHardCap() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let sentinelID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "large pinned sentinel",
            text: "sentinel",
            createdAt: Date(),
            contentBytes: Storage.maximumStorageBytes - 4
        )))
        try storage.setPinned(id: sentinelID, pinned: true)

        let imageID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .image,
            title: "OCR target",
            data: Data([1]),
            createdAt: Date().addingTimeInterval(1),
            contentBytes: 1
        )))
        try storage.setPinned(id: imageID, pinned: true)

        XCTAssertThrowsError(try storage.setOCRText("OCR text", forClipID: imageID)) { error in
            XCTAssertEqual(error as? StorageCapacityError, .pinnedItemsUseAllAvailableSpace)
        }
        XCTAssertNil(try storage.fetchClip(id: imageID)?.ocrText)
    }

    func testStarterSnippetsAreIdempotentAndHaveNoFakeContacts() throws {
        let storage = try Storage(inMemory: true, installStarterContent: true)
        try storage.installStarterSnippetsIfNeeded(force: false)
        try storage.installStarterSnippetsIfNeeded(force: false)

        let snippets = try storage.allSnippets()
        XCTAssertEqual(snippets.count, 6)
        try storage.installStarterSnippetsIfNeeded(force: true)
        XCTAssertEqual(try storage.allSnippets().count, 6)
        XCTAssertFalse(snippets.contains { snippet in
            snippet.content.contains("@") || snippet.content.contains("+7")
        })
    }

    func testSnippetReadsCanStopAtTheMenuLimit() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        for index in 0..<30 {
            _ = try storage.addSnippet(
                folderID: nil,
                title: "Bulk result \(index)",
                content: "bulk searchable content \(index)"
            )
        }

        XCTAssertEqual(try storage.allSnippets(limit: 20).count, 20)
        XCTAssertEqual(try storage.allSnippets().count, 30)
    }

    func testSnippetSummariesBoundTheReturnedPreview() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let content = String(repeating: "a", count: 800) + " unique-needle"
        let created = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Long snippet",
            content: content
        ))
        let id = try XCTUnwrap(created.id)

        let summary = try XCTUnwrap(storage.snippetSummaries().first)
        XCTAssertEqual(summary.id, id)
        XCTAssertEqual(summary.contentPreview.count, Storage.snippetPreviewCharacterLimit)
        XCTAssertTrue(summary.contentIsTruncated)
        XCTAssertFalse(summary.contentPreview.contains("unique-needle"))
        XCTAssertEqual(try storage.fetchSnippet(id: id)?.content, content)
    }

    func testLocalSnippetWritesEnforcePortableFieldLimits() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)

        XCTAssertThrowsError(try storage.addSnippet(
            folderID: nil,
            title: String(repeating: "t", count: Storage.maximumSnippetTitleCharacters + 1),
            content: "value"
        )) { error in
            XCTAssertEqual(error as? SnippetStorageError, .snippetTitleTooLong)
        }
        XCTAssertThrowsError(try storage.addSnippet(
            folderID: nil,
            title: "Title",
            content: String(repeating: "x", count: ClipboardCapturePolicy.maxTextBytes + 1)
        )) { error in
            XCTAssertEqual(error as? SnippetStorageError, .snippetContentTooLarge)
        }
        XCTAssertThrowsError(try storage.addFolder(
            title: String(repeating: "f", count: Storage.maximumSnippetTitleCharacters + 1)
        )) { error in
            XCTAssertEqual(error as? SnippetStorageError, .folderTitleTooLong)
        }
    }

    func testSnippetPinAndUsage() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Invoice reply",
            content: "Received {date}"
        ))
        let id = try XCTUnwrap(snippet.id)

        try storage.setSnippetPinned(id: id, pinned: true)
        try storage.markSnippetUsed(id: id)
        let fetched = try XCTUnwrap(storage.allSnippets().first)
        XCTAssertTrue(fetched.isPinned)
        XCTAssertEqual(fetched.useCount, 1)
        XCTAssertNotNil(fetched.lastUsedAt)
    }

    func testPinnedSnippetRanksFirst() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.addSnippet(
            folderID: nil,
            title: "Ordinary",
            content: "ordinary content"
        )
        let pinned = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Pinned with keyword",
            content: "important content"
        ))
        let pinnedID = try XCTUnwrap(pinned.id)
        try storage.setSnippetPinned(id: pinnedID, pinned: true)

        XCTAssertEqual(try storage.allSnippets().first?.id, pinnedID)
    }

    func testFolderRenamePersistsAndRejectsAnEmptyTitle() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        var folder = try XCTUnwrap(storage.addFolder(title: "Original"))
        folder.title = "  Renamed  "

        let updated = try storage.update(folder)
        XCTAssertEqual(updated.title, "Renamed")
        XCTAssertEqual(try storage.snippetFolders().first?.title, "Renamed")

        folder = updated
        folder.title = "   "
        XCTAssertThrowsError(try storage.update(folder)) { error in
            XCTAssertEqual(error as? SnippetStorageError, .emptyFolderTitle)
        }
        XCTAssertEqual(try storage.snippetFolders().first?.title, "Renamed")
    }

    func testSnippetMovePreservesFieldsAndAssignsDestinationOrder() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let sourceID = try XCTUnwrap(storage.addFolder(title: "Source")?.id)
        let destinationID = try XCTUnwrap(storage.addFolder(title: "Destination")?.id)
        let existingID = try XCTUnwrap(storage.addSnippet(
            folderID: destinationID,
            title: "Existing",
            content: "first"
        )?.id)
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: sourceID,
            title: "Move me",
            content: "Body {date}"
        ))
        let id = try XCTUnwrap(snippet.id)
        try storage.setSnippetPinned(id: id, pinned: true)
        try storage.markSnippetUsed(id: id)
        let before = try XCTUnwrap(storage.allSnippets().first)

        let moved = try storage.moveSnippet(id: id, toFolderID: destinationID)
        XCTAssertEqual(moved.folderID, destinationID)
        XCTAssertEqual(moved.sortIndex, 1)
        XCTAssertEqual(moved.title, before.title)
        XCTAssertEqual(moved.content, before.content)
        XCTAssertEqual(moved.isPinned, before.isPinned)
        XCTAssertEqual(moved.useCount, before.useCount)
        XCTAssertEqual(moved.lastUsedAt, before.lastUsedAt)
        XCTAssertEqual(try storage.allSnippets().filter { $0.folderID == destinationID }
            .sorted { $0.sortIndex < $1.sortIndex }.map(\.id), [existingID, id])

        let unfiled = try storage.moveSnippet(id: id, toFolderID: nil)
        XCTAssertNil(unfiled.folderID)
        XCTAssertEqual(unfiled.content, before.content)
    }

    func testSnippetEditDoesNotOverwriteNewerUsageMetadata() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        var staleEditorCopy = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Concurrent edit",
            content: "before"
        ))
        let id = try XCTUnwrap(staleEditorCopy.id)

        try storage.markSnippetUsed(id: id)
        staleEditorCopy.content = "after"
        let updated = try storage.update(staleEditorCopy)

        XCTAssertEqual(updated.content, "after")
        XCTAssertEqual(updated.useCount, 1)
        XCTAssertNotNil(updated.lastUsedAt)
    }

    func testDeletingFolderLeavesLiveSnippetsUnfiledWithMetadataIntact() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folderID = try XCTUnwrap(storage.addFolder(title: "Temporary")?.id)
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: folderID,
            title: "Keep me",
            content: "Preserved body"
        ))
        let id = try XCTUnwrap(snippet.id)
        try storage.setSnippetPinned(id: id, pinned: true)
        try storage.markSnippetUsed(id: id)
        let before = try XCTUnwrap(storage.allSnippets().first)

        try storage.deleteFolder(id: folderID)

        XCTAssertTrue(try storage.snippetFolders().isEmpty)
        let after = try XCTUnwrap(storage.allSnippets().first)
        XCTAssertNil(after.folderID)
        XCTAssertEqual(after.id, before.id)
        XCTAssertEqual(after.title, before.title)
        XCTAssertEqual(after.content, before.content)
        XCTAssertEqual(after.isPinned, before.isPinned)
        XCTAssertEqual(after.useCount, before.useCount)
        XCTAssertEqual(after.lastUsedAt, before.lastUsedAt)
        XCTAssertEqual(after.createdAt, before.createdAt)
        XCTAssertEqual(after.updatedAt, before.updatedAt)
    }

    @MainActor
    func testSnippetEditorSelectsTheFirstAvailableSnippetOnReload() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "First folder"))
        let folderID = try XCTUnwrap(folder.id)
        let first = try XCTUnwrap(storage.addSnippet(
            folderID: folderID,
            title: "Ready to edit",
            content: "Visible immediately"
        ))
        _ = try storage.addSnippet(folderID: nil, title: "Second", content: "Later")
        let model = SnippetsEditorModel(storage: storage)

        model.reload()

        XCTAssertEqual(model.selectedSnippetID, first.id)
        XCTAssertEqual(model.editorTitle, "Ready to edit")
        XCTAssertEqual(model.editorContent, "Visible immediately")
        XCTAssertEqual(model.saveState, .saved)
    }

    @MainActor
    func testSnippetEditorFlushesOldDraftBeforeSelectionChanges() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let first = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "First",
            content: "old"
        ))
        let second = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Second",
            content: "second"
        ))
        let firstID = try XCTUnwrap(first.id)
        let secondID = try XCTUnwrap(second.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.selectSnippet(firstID)

        model.editorContent = "saved before switching"
        model.editorChanged()
        model.selectSnippet(secondID)

        XCTAssertEqual(model.selectedSnippetID, secondID)
        XCTAssertEqual(
            try storage.allSnippets().first(where: { $0.id == firstID })?.content,
            "saved before switching"
        )
    }

    @MainActor
    func testSnippetEditorKeepsFailedDraftAndBlocksSelectionUntilRetrySucceeds() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let first = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "First",
            content: "first"
        ))
        let second = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Second",
            content: "second"
        ))
        let firstID = try XCTUnwrap(first.id)
        let secondID = try XCTUnwrap(second.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.selectSnippet(secondID)

        model.editorTitle = String(repeating: "x", count: 201)
        model.editorChanged()
        model.selectSnippet(firstID)

        XCTAssertEqual(model.selectedSnippetID, secondID)
        XCTAssertEqual(model.editorTitle, String(repeating: "x", count: 201))
        guard case .failed = model.saveState else {
            return XCTFail("A failed save must remain visible")
        }

        model.editorTitle = "Available"
        model.editorChanged()
        model.selectSnippet(firstID)

        XCTAssertEqual(model.selectedSnippetID, firstID)
        XCTAssertEqual(
            try storage.allSnippets().first(where: { $0.id == secondID })?.title,
            "Available"
        )
    }

    @MainActor
    func testSnippetEditorCancelsStaleDraftWhenFieldsReturnToSavedValue() async throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Original",
            content: "Body"
        ))
        let id = try XCTUnwrap(snippet.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.selectSnippet(id)

        model.editorTitle = "Intermediate"
        model.editorChanged()
        model.editorTitle = "Original"
        model.editorChanged()
        try await Task.sleep(for: .milliseconds(450))

        XCTAssertTrue(model.flushPendingSave())
        XCTAssertEqual(model.saveState, .saved)
        XCTAssertEqual(
            try storage.allSnippets().first(where: { $0.id == id })?.title,
            "Original"
        )
    }

    @MainActor
    func testSnippetEditorCanReturnFromFailedDraftToSavedValue() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let first = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "First",
            content: "first"
        ))
        let second = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Second",
            content: "second"
        ))
        let firstID = try XCTUnwrap(first.id)
        let secondID = try XCTUnwrap(second.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.selectSnippet(secondID)

        model.editorTitle = String(repeating: "x", count: 201)
        model.editorChanged()
        model.selectSnippet(firstID)
        guard case .failed = model.saveState else {
            return XCTFail("Oversized title must fail before the revert")
        }

        model.editorTitle = "Second"
        model.editorChanged()
        model.selectSnippet(firstID)

        XCTAssertEqual(model.selectedSnippetID, firstID)
        XCTAssertEqual(
            try storage.allSnippets().first(where: { $0.id == secondID })?.title,
            "Second"
        )
    }

    @MainActor
    func testSnippetEditorKeepsDraftWhenDeletionFails() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Keep draft",
            content: "old"
        ))
        let id = try XCTUnwrap(snippet.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload()
        model.selectSnippet(id)
        model.editorContent = "unsaved text"
        model.editorChanged()

        try storage.deleteSnippet(id: id)
        model.deleteSelected()

        XCTAssertEqual(model.selectedSnippetID, id)
        XCTAssertEqual(model.editorContent, "unsaved text")
        guard case .failed = model.saveState else {
            return XCTFail("Failed deletion must retain the draft")
        }
        XCTAssertFalse(model.flushPendingSave())
    }

    func testSnippetDeleteUndoRestoresExactMetadataAndSurvivesMissingFolder() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Reusable"))
        let folderID = try XCTUnwrap(folder.id)
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: folderID,
            title: "Exact undo",
            content: "Preserve everything {date}"
        ))
        let id = try XCTUnwrap(snippet.id)
        try storage.setSnippetPinned(id: id, pinned: true)
        try storage.markSnippetUsed(id: id)
        let original = try XCTUnwrap(storage.allSnippets().first)

        let removed = try XCTUnwrap(storage.removeSnippet(id: id))
        XCTAssertTrue(try storage.allSnippets().isEmpty)
        try storage.restoreSnippet(removed)
        XCTAssertEqual(try storage.allSnippets().first, original)

        let removedAgain = try XCTUnwrap(storage.removeSnippet(id: id))
        try storage.deleteFolder(id: folderID)
        try storage.restoreSnippet(removedAgain)
        let restoredWithoutFolder = try XCTUnwrap(storage.allSnippets().first)
        XCTAssertNil(restoredWithoutFolder.folderID)
        XCTAssertEqual(restoredWithoutFolder.id, original.id)
        XCTAssertEqual(restoredWithoutFolder.isPinned, original.isPinned)
        XCTAssertEqual(restoredWithoutFolder.useCount, original.useCount)
        XCTAssertEqual(restoredWithoutFolder.lastUsedAt, original.lastUsedAt)
        XCTAssertEqual(restoredWithoutFolder.createdAt, original.createdAt)
        XCTAssertEqual(restoredWithoutFolder.updatedAt, original.updatedAt)
    }

    func testV2DatabaseMigratesWithoutLosingClipOrSnippet() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("neclip-v2-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("fixture.sqlite").path

        let legacy = try DatabaseQueue(path: path)
        try legacy.write { db in
            try db.execute(sql: """
                CREATE TABLE clip (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    kind TEXT NOT NULL,
                    title TEXT NOT NULL,
                    text TEXT,
                    data BLOB,
                    appBundleID TEXT,
                    createdAt DATETIME NOT NULL,
                    rtf BLOB,
                    ocrText TEXT
                );
                CREATE INDEX clip_on_createdAt ON clip(createdAt);
                CREATE TABLE snippetFolder (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    title TEXT NOT NULL,
                    sortIndex INTEGER NOT NULL DEFAULT 0
                );
                CREATE TABLE snippet (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    folderID INTEGER NOT NULL REFERENCES snippetFolder(id) ON DELETE CASCADE,
                    title TEXT NOT NULL,
                    content TEXT NOT NULL,
                    sortIndex INTEGER NOT NULL DEFAULT 0
                );
                CREATE INDEX snippet_on_folderID ON snippet(folderID);
                CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY);
                INSERT INTO grdb_migrations(identifier) VALUES ('v1'), ('v2');
                INSERT INTO clip(kind, title, text, ocrText, createdAt)
                    VALUES (
                        'text', 'legacy clip', 'legacy body Привет',
                        'распознанный OCR', CURRENT_TIMESTAMP
                    );
                INSERT INTO snippetFolder(title, sortIndex) VALUES ('Legacy', 0);
                INSERT INTO snippet(folderID, title, content, sortIndex)
                    VALUES (1, 'legacy snippet', 'legacy snippet body', 0);
                """)
        }

        let migrated = try Storage(path: path, installStarterContent: false)
        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(try migrated.summaries().first?.title, "legacy clip")
        let migratedClipID = try XCTUnwrap(try migrated.summaries().first?.id)
        XCTAssertEqual(
            try migrated.fetchClip(id: migratedClipID)?.contentBytes,
            Int64("legacy body Привет".utf8.count + "распознанный OCR".utf8.count)
        )
        XCTAssertEqual(try migrated.allSnippets().first?.title, "legacy snippet")
        XCTAssertEqual(try migrated.allSnippets().first?.folderID, 1)

        let deduplicatedID = try migrated.insert(ClipItem(
            kind: .text,
            title: "legacy clip copied again",
            text: "legacy body Привет",
            createdAt: Date().addingTimeInterval(1)
        ))
        XCTAssertEqual(deduplicatedID, migratedClipID)
        XCTAssertEqual(migrated.count, 1)
        XCTAssertNotNil(try migrated.fetchClip(id: migratedClipID)?.contentHash)
    }

    func testMenuReadsStayFastAtMaximumHistoryAfterLargeMigration() throws {
        Settings.historyLimit = 1_000
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("neclip-10k-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("fixture.sqlite").path

        let legacy = try DatabaseQueue(path: path)
        try legacy.write { db in
            try db.execute(sql: """
                CREATE TABLE clip (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, kind TEXT NOT NULL,
                    title TEXT NOT NULL, text TEXT, data BLOB, appBundleID TEXT,
                    createdAt DATETIME NOT NULL, rtf BLOB, ocrText TEXT
                );
                CREATE INDEX clip_on_createdAt ON clip(createdAt);
                CREATE TABLE snippetFolder (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
                    sortIndex INTEGER NOT NULL DEFAULT 0
                );
                CREATE TABLE snippet (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    folderID INTEGER NOT NULL REFERENCES snippetFolder(id) ON DELETE CASCADE,
                    title TEXT NOT NULL, content TEXT NOT NULL,
                    sortIndex INTEGER NOT NULL DEFAULT 0
                );
                CREATE INDEX snippet_on_folderID ON snippet(folderID);
                CREATE TABLE grdb_migrations (identifier TEXT NOT NULL PRIMARY KEY);
                INSERT INTO grdb_migrations(identifier) VALUES ('v1'), ('v2');
                WITH RECURSIVE counter(value) AS (
                    SELECT 1 UNION ALL SELECT value + 1 FROM counter WHERE value < 10000
                )
                INSERT INTO clip(kind, title, text, appBundleID, createdAt)
                SELECT 'text', 'entry ' || value,
                       CASE WHEN value = 9999 THEN 'unique needle9999' ELSE 'ordinary value ' || value END,
                       'com.example.fixture', CURRENT_TIMESTAMP
                FROM counter;
                """)
        }

        let storage = try Storage(path: path, installStarterContent: false)
        XCTAssertEqual(storage.count, 1_000)
        let started = Date()
        let matches = try storage.summaries(limit: 40)
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertEqual(matches.count, 40)
        XCTAssertLessThan(elapsed, 0.05, "Bounded recent-item reads took \(elapsed) seconds")

        let menuStarted = Date()
        XCTAssertEqual(
            try storage.summaries(limit: 101, unpinnedOnly: true).count,
            101
        )
        XCTAssertEqual(try storage.recentClipIDs(limit: 50).count, 50)
        let menuElapsed = Date().timeIntervalSince(menuStarted)
        XCTAssertLessThan(menuElapsed, 0.05, "Menu summary reads took \(menuElapsed) seconds")
    }

    func testExternalDatabaseCopyMigratesWithoutCountLossWhenProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["NECLIP_EXTERNAL_DB"], !path.isEmpty else {
            throw XCTSkip("Set NECLIP_EXTERNAL_DB to a disposable SQLite copy")
        }
        let before = try DatabaseQueue(path: path).read { db -> (Int, Int) in
            let clips = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM clip") ?? 0
            let snippets = (try? Int.fetchOne(db, sql: "SELECT COUNT(*) FROM snippet")) ?? 0
            return (clips, snippets)
        }
        let migrated = try Storage(path: path, installStarterContent: false)
        XCTAssertEqual(migrated.count, before.0)
        XCTAssertEqual(try migrated.allSnippets().count, before.1)
        _ = try migrated.summaries(limit: 1)
    }

    func testMenuSnippetSnapshotIsBoundedAndLoadsOnlyVisibleFolders() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        for index in 0..<4 {
            let folder = try XCTUnwrap(storage.addFolder(title: "Folder \(index)"))
            _ = try storage.addSnippet(
                folderID: try XCTUnwrap(folder.id),
                title: "Snippet \(index)",
                content: "Value \(index)"
            )
        }

        let snapshot = try storage.menuSnippetSnapshot(limit: 2)
        XCTAssertEqual(snapshot.snippets.count, 2)
        XCTAssertTrue(snapshot.hasMore)
        XCTAssertEqual(
            Set(snapshot.snippets.compactMap(\.folderID)),
            Set(snapshot.folders.compactMap(\.id))
        )
        XCTAssertLessThan(snapshot.folders.count, try storage.snippetFolders().count)
        XCTAssertTrue(snapshot.snippets.allSatisfy {
            $0.contentPreview.count <= Storage.snippetPreviewCharacterLimit
        })
        XCTAssertEqual(try storage.allSnippets().count, 4)
    }

    func testDeleteAllUserDataRemovesHistorySnippetsAndFoldersAtomically() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.insert(ClipItem(
            kind: .text,
            title: "Private value",
            text: "Private value",
            createdAt: Date()
        ))
        let folder = try XCTUnwrap(storage.addFolder(title: "Private folder"))
        _ = try storage.addSnippet(
            folderID: try XCTUnwrap(folder.id),
            title: "Private snippet",
            content: "Private value"
        )

        try storage.deleteAllUserData()

        XCTAssertEqual(storage.count, 0)
        XCTAssertTrue(try storage.allSnippets().isEmpty)
        XCTAssertTrue(try storage.snippetFolders().isEmpty)
    }

    func testPartialHistoryCleanupDeletesOnlyRecentUnpinnedItems() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let now = Date()
        let oldID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "old",
            text: "old partial cleanup value",
            createdAt: now.addingTimeInterval(-7_200)
        )))
        let recentID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "recent",
            text: "recent partial cleanup value",
            createdAt: now.addingTimeInterval(-60)
        )))
        let pinnedID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "pinned",
            text: "pinned partial cleanup value",
            createdAt: now.addingTimeInterval(-30)
        )))
        try storage.setPinned(id: pinnedID, pinned: true)

        let removed = try storage.clearHistory(
            includePinned: false,
            createdAfter: now.addingTimeInterval(-3_600)
        )

        XCTAssertEqual(removed, 1)
        XCTAssertNotNil(try storage.fetchClip(id: oldID))
        XCTAssertNil(try storage.fetchClip(id: recentID))
        XCTAssertNotNil(try storage.fetchClip(id: pinnedID))
    }
}

final class SnippetRendererTests: XCTestCase {
    func testLocalPlaceholdersAreDeterministicAndOffline() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let result = try SnippetRenderer.render(
            "{date} | {time} | {clipboard}",
            clipboard: "local value",
            date: date,
            locale: Locale(identifier: "en_US_POSIX")
        )
        XCTAssertTrue(result.contains("local value"))
        XCTAssertFalse(result.contains("{date}"))
        XCTAssertFalse(result.contains("{time}"))
    }
}
