import GRDB
import XCTest
@testable import NeClip

final class SearchRetirementTests: XCTestCase {
    func testLegacyKeywordImportIsIgnoredAndNeverBlocksEditingOrExport() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let legacy = Data("""
            {"version":1,"snippets":[
              {"folder":"Ответы","title":"Первый","content":"А","keyword":";same","isPinned":true},
              {"folder":"Ответы","title":"Второй","content":"Б","keyword":";SAME","isPinned":false}
            ]}
            """.utf8)
        XCTAssertEqual(try storage.importSnippetData(legacy), 2)
        XCTAssertEqual(try storage.importSnippetData(legacy), 0)
        let snippets = try storage.allSnippets()
        XCTAssertEqual(Set(snippets.map(\.title)), ["Первый", "Второй"])
        var edited = try XCTUnwrap(snippets.first { $0.title == "Первый" })
        XCTAssertFalse(edited.isPinned)
        edited.content = "Изменено без ключа"
        XCTAssertEqual(try storage.update(edited).content, "Изменено без ключа")

        let exported = try JSONDecoder().decode(SnippetTransferDocument.self, from: storage.exportSnippetData())
        XCTAssertEqual(exported.snippets.count, 2)
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: storage.exportSnippetData()) as? [String: Any])
        let records = try XCTUnwrap(raw["snippets"] as? [[String: Any]])
        XCTAssertTrue(records.allSatisfy { $0["keyword"] == nil })
    }

    func testMigrationRetiresOnlyDerivedSearchDataAndPreservesLegacyContent() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("neclip-retire-search-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("fixture.sqlite").path
        let body = "Старый текст 👩🏽‍💻\n" + String(repeating: "x", count: 100_000)
        let image = Data(repeating: 42, count: 4096)
        let snippetID: Int64
        let clipID: Int64
        let folderID: Int64
        do {
            let storage = try Storage(path: path, installStarterContent: false)
            folderID = try XCTUnwrap(storage.addFolder(title: "Старая папка")?.id)
            snippetID = try XCTUnwrap(storage.addSnippet(folderID: folderID, title: "Старый", content: body)?.id)
            try storage.setSnippetPinned(id: snippetID, pinned: true)
            try storage.markSnippetUsed(id: snippetID)
            clipID = try XCTUnwrap(storage.insert(ClipItem(kind: .image, title: "Image", data: image, createdAt: Date())))
            try storage.setPinned(id: clipID, pinned: true)
        }
        // Reproduce a v6 database with legacy keys and populated FTS tables.
        do {
            let legacy = try DatabaseQueue(path: path)
            try legacy.write { db in
                try db.execute(sql: """
                    DELETE FROM grdb_migrations WHERE identifier IN ('v7-retire-search', 'v8-retire-pins');
                    UPDATE snippet SET keyword = ';legacy';
                    CREATE UNIQUE INDEX snippet_keyword_unique ON snippet(lower(keyword))
                        WHERE keyword IS NOT NULL AND keyword <> '';
                    CREATE VIRTUAL TABLE clipSearch USING fts5(title, text, ocrText, appBundleID,
                        content='clip', content_rowid='id');
                    CREATE VIRTUAL TABLE snippetSearch USING fts5(title, content, keyword,
                        content='snippet', content_rowid='id');
                    INSERT INTO clipSearch(clipSearch) VALUES ('rebuild');
                    INSERT INTO snippetSearch(snippetSearch) VALUES ('rebuild');
                    """)
                for table in ["clip", "snippet"] {
                    for (suffix, event) in [("ai", "INSERT"), ("ad", "DELETE"), ("au", "UPDATE")] {
                        try db.execute(sql: "CREATE TRIGGER \(table)Search_\(suffix) AFTER \(event) ON \(table) BEGIN SELECT 1; END;")
                    }
                }
            }
        }
        let migrated = try Storage(path: path, installStarterContent: false)
        var snippet = try XCTUnwrap(migrated.fetchSnippet(id: snippetID))
        XCTAssertEqual(snippet.content, body)
        XCTAssertEqual(snippet.folderID, folderID)
        XCTAssertFalse(snippet.isPinned)
        XCTAssertEqual(snippet.useCount, 1)
        let clip = try XCTUnwrap(migrated.fetchClip(id: clipID))
        XCTAssertEqual(clip.data, image)
        XCTAssertFalse(clip.isPinned)
        let dbQueue = try DatabaseQueue(path: path)
        try dbQueue.read { db in
            let objects = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master")
            XCTAssertFalse(objects.contains { $0.hasPrefix("clipSearch") || $0.hasPrefix("snippetSearch") })
            XCTAssertFalse(objects.contains("snippet_keyword_unique"))
            XCTAssertEqual(try String.fetchOne(db, sql: "SELECT keyword FROM snippet WHERE id = ?", arguments: [snippetID]), ";legacy")
        }
        snippet.content = "Saved after migration"
        XCTAssertEqual(try migrated.update(snippet).content, "Saved after migration")
        let removed = try XCTUnwrap(migrated.removeSnippet(id: snippetID))
        try migrated.restoreSnippet(removed)
        XCTAssertEqual(try migrated.fetchSnippet(id: snippetID)?.content, "Saved after migration")
        XCTAssertEqual(try Storage(path: path, installStarterContent: false).count, 1, "Reopening is idempotent")
    }
}
