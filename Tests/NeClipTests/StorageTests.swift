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

    func testSummarySearchFetchesRUENAndDigitsWithoutOriginalBlob() throws {
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

        XCTAssertEqual(try storage.summaries(search: "прив").map(\.id), [id])
        XCTAssertEqual(try storage.summaries(search: "NeCl").map(\.id), [id])
        XCTAssertEqual(try storage.summaries(search: "2026").map(\.id), [id])

        let literalID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "literal %_ marker",
            text: "percent and underscore",
            createdAt: Date().addingTimeInterval(1)
        )))
        XCTAssertEqual(try storage.summaries(search: "%_").map(\.id), [literalID])

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

    func testStarterSnippetsAreIdempotentSearchableAndHaveNoFakeContacts() throws {
        let storage = try Storage(inMemory: true, installStarterContent: true)
        try storage.installStarterSnippetsIfNeeded(force: false)
        try storage.installStarterSnippetsIfNeeded(force: false)

        let snippets = try storage.allSnippets()
        XCTAssertEqual(snippets.count, 6)
        XCTAssertEqual(try storage.allSnippets(search: "thanks").count, 1)
        XCTAssertFalse(snippets.contains { snippet in
            snippet.content.contains("@") || snippet.content.contains("+7")
        })
    }

    func testSnippetKeywordNormalizationPinAndUsage() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Invoice reply",
            content: "Received {date}",
            keyword: "invoice"
        ))
        let id = try XCTUnwrap(snippet.id)
        XCTAssertEqual(snippet.keyword, ";invoice")

        try storage.setSnippetPinned(id: id, pinned: true)
        try storage.markSnippetUsed(id: id)
        let fetched = try XCTUnwrap(storage.allSnippets(search: "invoice").first)
        XCTAssertTrue(fetched.isPinned)
        XCTAssertEqual(fetched.useCount, 1)
        XCTAssertNotNil(fetched.lastUsedAt)
    }

    func testPinnedSnippetRanksFirstWithoutSearchQuery() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.addSnippet(
            folderID: nil,
            title: "Ordinary",
            content: "ordinary content"
        )
        let pinned = try XCTUnwrap(storage.addSnippet(
            folderID: nil,
            title: "Pinned with keyword",
            content: "important content",
            keyword: "important"
        ))
        let pinnedID = try XCTUnwrap(pinned.id)
        try storage.setSnippetPinned(id: pinnedID, pinned: true)

        XCTAssertEqual(try storage.allSnippets().first?.id, pinnedID)
    }

    func testSnippetDeleteUndoRestoresExactMetadataAndSurvivesMissingFolder() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folder = try XCTUnwrap(storage.addFolder(title: "Reusable"))
        let folderID = try XCTUnwrap(folder.id)
        let snippet = try XCTUnwrap(storage.addSnippet(
            folderID: folderID,
            title: "Exact undo",
            content: "Preserve everything {date}",
            keyword: "undo"
        ))
        let id = try XCTUnwrap(snippet.id)
        try storage.setSnippetPinned(id: id, pinned: true)
        try storage.markSnippetUsed(id: id)
        let original = try XCTUnwrap(storage.allSnippets(search: "undo").first)

        let removed = try XCTUnwrap(storage.removeSnippet(id: id))
        XCTAssertTrue(try storage.allSnippets(search: "undo").isEmpty)
        try storage.restoreSnippet(removed)
        XCTAssertEqual(try storage.allSnippets(search: "undo").first, original)

        let removedAgain = try XCTUnwrap(storage.removeSnippet(id: id))
        storage.deleteFolder(id: folderID)
        try storage.restoreSnippet(removedAgain)
        let restoredWithoutFolder = try XCTUnwrap(storage.allSnippets(search: "undo").first)
        XCTAssertNil(restoredWithoutFolder.folderID)
        XCTAssertEqual(restoredWithoutFolder.id, original.id)
        XCTAssertEqual(restoredWithoutFolder.keyword, original.keyword)
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
        XCTAssertEqual(try migrated.summaries(search: "legacy").first?.title, "legacy clip")
        let migratedClipID = try XCTUnwrap(try migrated.summaries(search: "legacy").first?.id)
        XCTAssertEqual(
            try migrated.fetchClip(id: migratedClipID)?.contentBytes,
            Int64("legacy body Привет".utf8.count + "распознанный OCR".utf8.count)
        )
        XCTAssertEqual(try migrated.allSnippets(search: "legacy").first?.title, "legacy snippet")
        XCTAssertEqual(try migrated.allSnippets().first?.folderID, 1)
    }

    func testSearchOnTenThousandMigratedRowsStaysFast() throws {
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
        let started = Date()
        let matches = try storage.summaries(limit: 40, search: "needle9999")
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertEqual(matches.count, 1)
        XCTAssertLessThan(elapsed, 0.05, "10k FTS search took \(elapsed) seconds")
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
}

final class SnippetRendererTests: XCTestCase {
    func testLocalPlaceholdersAreDeterministicAndOffline() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let result = SnippetRenderer.render(
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
