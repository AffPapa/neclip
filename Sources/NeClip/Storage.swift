import CryptoKit
import Foundation
import GRDB

enum ClipKind: String, Codable, DatabaseValueConvertible, Sendable {
    case text
    case image
    case file
}

struct ClipItem: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Sendable {
    static let databaseTableName = "clip"

    var id: Int64?
    var kind: ClipKind
    var title: String
    var text: String? = nil
    var data: Data? = nil
    var rtf: Data? = nil
    var ocrText: String? = nil
    var thumbnail: Data? = nil
    var appBundleID: String? = nil
    var createdAt: Date
    var contentBytes: Int64 = 0
    var contentHash: String? = nil
    var isPinned: Bool = false
    var pinnedAt: Date? = nil

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// The only representation used by the menu. It intentionally cannot carry
/// original image/RTF BLOBs.
struct ClipSummary: Identifiable, Hashable, Sendable {
    let id: Int64
    let kind: ClipKind
    let title: String
    let text: String?
    let thumbnail: Data?
    let appBundleID: String?
    let createdAt: Date
    let isPinned: Bool
}

struct RemovedClip: Sendable {
    let item: ClipItem
}

struct RemovedSnippet: Sendable {
    let item: Snippet
}

enum StorageCapacityError: LocalizedError, Equatable {
    case pinnedItemsUseAllAvailableSpace

    var errorDescription: String? {
        "Закреплённые элементы заняли весь лимит хранилища"
    }
}

struct SnippetFolder: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "snippetFolder"

    var id: Int64?
    var title: String
    var sortIndex: Int

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

struct Snippet: Codable, FetchableRecord, MutablePersistableRecord, Identifiable, Hashable, Sendable {
    static let databaseTableName = "snippet"

    var id: Int64?
    var folderID: Int64?
    var title: String
    var content: String
    var sortIndex: Int = 0
    var keyword: String? = nil
    var isPinned: Bool = false
    var useCount: Int = 0
    var lastUsedAt: Date? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Notification.Name {
    static let neClipStorageDidChange = Notification.Name("org.affpapa.neclip.storageDidChange")
}

final class Storage: @unchecked Sendable {
    static let maximumStorageBytes: Int64 = 250 * 1024 * 1024

    static let shared: Storage = {
        do {
            return try Storage()
        } catch {
            // Clipboard history must never make the menu-bar app crash-loop.
            do {
                return try Storage(inMemory: true, startupError: error)
            } catch {
                fatalError("NeClip could not initialize SQLite: \(error)")
            }
        }
    }()

    let startupError: Error?
    private let dbQueue: DatabaseQueue
    private let installStarterContent: Bool

    init(
        path: String? = nil,
        inMemory: Bool = false,
        installStarterContent: Bool = true,
        startupError: Error? = nil
    ) throws {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
            try db.execute(sql: "PRAGMA secure_delete = FAST")
        }

        if inMemory {
            dbQueue = try DatabaseQueue(configuration: configuration)
        } else {
            let databasePath: String
            if let path {
                databasePath = path
            } else {
                let directory: URL
#if DEBUG
                let dataDirectoryOverride = ProcessInfo.processInfo.environment["NECLIP_DATA_DIR"]
#else
                let dataDirectoryOverride: String? = nil
#endif
                if let override = dataDirectoryOverride, !override.isEmpty {
                    directory = URL(fileURLWithPath: override, isDirectory: true).standardizedFileURL
                } else {
                    directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("NeClip", isDirectory: true)
                }
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
                databasePath = directory.appendingPathComponent("neclip.sqlite").path
            }
            dbQueue = try DatabaseQueue(path: databasePath, configuration: configuration)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: databasePath)
        }

        self.startupError = startupError
        self.installStarterContent = installStarterContent
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "clip") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("kind", .text).notNull()
                t.column("title", .text).notNull()
                t.column("text", .text)
                t.column("data", .blob)
                t.column("appBundleID", .text)
                t.column("createdAt", .datetime).notNull().indexed()
            }
        }
        migrator.registerMigration("v2") { db in
            try db.alter(table: "clip") { t in
                t.add(column: "rtf", .blob)
                t.add(column: "ocrText", .text)
            }
            try db.create(table: "snippetFolder") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("title", .text).notNull()
                t.column("sortIndex", .integer).notNull().defaults(to: 0)
            }
            try db.create(table: "snippet") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("folderID", .integer).notNull().indexed()
                    .references("snippetFolder", onDelete: .cascade)
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("sortIndex", .integer).notNull().defaults(to: 0)
            }
        }
        migrator.registerMigration("v3-fast-local-core") { db in
            try db.alter(table: "clip") { t in
                t.add(column: "thumbnail", .blob)
                t.add(column: "contentBytes", .integer).notNull().defaults(to: 0)
                t.add(column: "contentHash", .text)
                t.add(column: "isPinned", .boolean).notNull().defaults(to: false)
                t.add(column: "pinnedAt", .datetime)
            }
            try db.create(index: "clip_contentHash", on: "clip", columns: ["contentHash"])
            try db.create(index: "clip_pinned_created", on: "clip", columns: ["isPinned", "createdAt"])
            try db.execute(sql: """
                UPDATE clip
                SET contentBytes = COALESCE(length(CAST(text AS BLOB)), 0)
                    + COALESCE(length(data), 0)
                    + COALESCE(length(rtf), 0)
                    + COALESCE(length(thumbnail), 0)
                """)

            try db.execute(sql: "DROP INDEX IF EXISTS snippet_on_folderID")
            try db.rename(table: "snippet", to: "snippetLegacy")
            try db.create(table: "snippet") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("folderID", .integer).indexed()
                    .references("snippetFolder", onDelete: .setNull)
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("sortIndex", .integer).notNull().defaults(to: 0)
                t.column("keyword", .text)
                t.column("isPinned", .boolean).notNull().defaults(to: false)
                t.column("useCount", .integer).notNull().defaults(to: 0)
                t.column("lastUsedAt", .datetime)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.execute(sql: """
                INSERT INTO snippet
                    (id, folderID, title, content, sortIndex, createdAt, updatedAt)
                SELECT id, folderID, title, content, sortIndex, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                FROM snippetLegacy
                """)
            try db.drop(table: "snippetLegacy")
            try db.execute(sql: """
                CREATE UNIQUE INDEX snippet_keyword_unique
                ON snippet(lower(keyword))
                WHERE keyword IS NOT NULL AND keyword <> ''
                """)

            try db.create(table: "appMetadata") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }

            try db.execute(sql: """
                CREATE VIRTUAL TABLE clipSearch USING fts5(
                    title, text, ocrText, appBundleID,
                    content='clip', content_rowid='id',
                    tokenize='unicode61 remove_diacritics 2'
                )
                """)
            try db.execute(sql: """
                CREATE TRIGGER clipSearch_ai AFTER INSERT ON clip BEGIN
                    INSERT INTO clipSearch(rowid, title, text, ocrText, appBundleID)
                    VALUES (new.id, new.title, new.text, new.ocrText, new.appBundleID);
                END;
                CREATE TRIGGER clipSearch_ad AFTER DELETE ON clip BEGIN
                    INSERT INTO clipSearch(clipSearch, rowid, title, text, ocrText, appBundleID)
                    VALUES ('delete', old.id, old.title, old.text, old.ocrText, old.appBundleID);
                END;
                CREATE TRIGGER clipSearch_au AFTER UPDATE ON clip BEGIN
                    INSERT INTO clipSearch(clipSearch, rowid, title, text, ocrText, appBundleID)
                    VALUES ('delete', old.id, old.title, old.text, old.ocrText, old.appBundleID);
                    INSERT INTO clipSearch(rowid, title, text, ocrText, appBundleID)
                    VALUES (new.id, new.title, new.text, new.ocrText, new.appBundleID);
                END
                """)
            try db.execute(sql: "INSERT INTO clipSearch(clipSearch) VALUES ('rebuild')")

            try db.execute(sql: """
                CREATE VIRTUAL TABLE snippetSearch USING fts5(
                    title, content, keyword,
                    content='snippet', content_rowid='id',
                    tokenize='unicode61 remove_diacritics 2'
                )
                """)
            try db.execute(sql: """
                CREATE TRIGGER snippetSearch_ai AFTER INSERT ON snippet BEGIN
                    INSERT INTO snippetSearch(rowid, title, content, keyword)
                    VALUES (new.id, new.title, new.content, new.keyword);
                END;
                CREATE TRIGGER snippetSearch_ad AFTER DELETE ON snippet BEGIN
                    INSERT INTO snippetSearch(snippetSearch, rowid, title, content, keyword)
                    VALUES ('delete', old.id, old.title, old.content, old.keyword);
                END;
                CREATE TRIGGER snippetSearch_au AFTER UPDATE ON snippet BEGIN
                    INSERT INTO snippetSearch(snippetSearch, rowid, title, content, keyword)
                    VALUES ('delete', old.id, old.title, old.content, old.keyword);
                    INSERT INTO snippetSearch(rowid, title, content, keyword)
                    VALUES (new.id, new.title, new.content, new.keyword);
                END
                """)
            try db.execute(sql: "INSERT INTO snippetSearch(snippetSearch) VALUES ('rebuild')")
        }
        // Recount all payloads in a new migration so databases that already
        // completed v3 also gain exact OCR byte accounting.
        migrator.registerMigration("v4-ocr-byte-accounting") { db in
            try db.execute(sql: """
                UPDATE clip
                SET contentBytes = COALESCE(length(CAST(text AS BLOB)), 0)
                    + COALESCE(length(CAST(ocrText AS BLOB)), 0)
                    + COALESCE(length(data), 0)
                    + COALESCE(length(rtf), 0)
                    + COALESCE(length(thumbnail), 0)
                """)
        }
        try migrator.migrate(dbQueue)
        // Apply retention immediately after a migration/recount. Only ordinary
        // history can be removed; pinned clips remain protected even if they
        // alone exceed the cap, in which case new captures fail explicitly.
        try dbQueue.write { db in
            try trim(db)
        }
    }

    // MARK: - Clips

    @discardableResult
    func insert(_ newItem: ClipItem) throws -> Int64? {
        var item = newItem
        if item.contentBytes == 0 {
            item.contentBytes = Int64(
                (item.text?.utf8.count ?? 0)
                    + (item.ocrText?.utf8.count ?? 0)
                    + (item.data?.count ?? 0)
                    + (item.rtf?.count ?? 0)
                    + (item.thumbnail?.count ?? 0)
            )
        }
        if item.contentHash == nil {
            item.contentHash = Self.hash(for: item)
        }

        let id = try dbQueue.write { db -> Int64? in
            var existing: ClipItem?
            if let hash = item.contentHash {
                existing = try ClipItem
                    .filter(Column("contentHash") == hash && Column("kind") == item.kind.rawValue)
                    .fetchOne(db)
            }
            // v1/v2 rows have no SHA-256. Match an old payload once, then
            // populate its hash so subsequent copies use the index.
            if existing == nil {
                switch item.kind {
                case .text, .file:
                    if let text = item.text {
                        existing = try ClipItem
                            .filter(Column("kind") == item.kind.rawValue && Column("text") == text)
                            .fetchOne(db)
                    }
                case .image:
                    if let data = item.data {
                        existing = try ClipItem
                            .filter(Column("kind") == item.kind.rawValue && Column("data") == data)
                            .fetchOne(db)
                    }
                }
            }
            if var existing {
                existing.title = item.title
                existing.text = item.text ?? existing.text
                existing.data = item.data ?? existing.data
                existing.rtf = item.rtf ?? existing.rtf
                existing.thumbnail = item.thumbnail ?? existing.thumbnail
                existing.appBundleID = item.appBundleID
                existing.createdAt = item.createdAt
                existing.contentBytes = Self.payloadBytes(existing)
                existing.contentHash = item.contentHash
                try ensureCapacityForItem(existing, replacing: existing.id, in: db)
                try existing.update(db)
                try trim(db)
                return existing.id
            }
            try ensureCapacityForItem(item, replacing: nil, in: db)
            try item.insert(db)
            try trim(db)
            return item.id
        }
        notifyChange()
        return id
    }

    func summaries(
        limit: Int = 60,
        search: String? = nil,
        pinnedOnly: Bool = false,
        unpinnedOnly: Bool = false
    ) throws -> [ClipSummary] {
        try recentSummaries(
            limit: limit,
            search: search,
            pinnedOnly: pinnedOnly,
            unpinnedOnly: unpinnedOnly
        )
    }

    func recentSummaries(
        limit: Int = 60,
        search: String? = nil,
        pinnedOnly: Bool = false,
        unpinnedOnly: Bool = false,
        offset: Int = 0
    ) throws -> [ClipSummary] {
        try dbQueue.read { db in
            var sql = """
                SELECT c.id, c.kind, c.title,
                       substr(COALESCE(c.text, c.ocrText, ''), 1, 280) AS text,
                       c.thumbnail, c.appBundleID, c.createdAt, c.isPinned
                FROM clip c
                """
            var conditions: [String] = []
            var arguments = StatementArguments()
            if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let match = Self.ftsMatch(search) {
                    sql += " JOIN clipSearch ON clipSearch.rowid = c.id"
                    conditions.append("clipSearch MATCH ?")
                    arguments += [match]
                } else {
                    conditions.append("""
                        (c.title LIKE ? ESCAPE '\\' OR c.text LIKE ? ESCAPE '\\'
                         OR c.ocrText LIKE ? ESCAPE '\\' OR c.appBundleID LIKE ? ESCAPE '\\')
                        """)
                    let pattern = Self.likePattern(search)
                    arguments += [pattern, pattern, pattern, pattern]
                }
            }
            if pinnedOnly { conditions.append("c.isPinned = 1") }
            if unpinnedOnly { conditions.append("c.isPinned = 0") }
            if !conditions.isEmpty { sql += " WHERE " + conditions.joined(separator: " AND ") }
            sql += " ORDER BY c.isPinned DESC, c.pinnedAt DESC, c.createdAt DESC LIMIT ? OFFSET ?"
            arguments += [max(1, limit), max(0, offset)]
            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            return rows.compactMap(Self.summary(from:))
        }
    }

    func fetchClip(id: Int64) throws -> ClipItem? {
        try dbQueue.read { db in try ClipItem.fetchOne(db, key: id) }
    }

    func recent(limit: Int? = nil, search: String? = nil) -> [ClipItem] {
        (try? dbQueue.read { db in
            var request = ClipItem.order(Column("isPinned").desc, Column("createdAt").desc)
            if let search, !search.isEmpty {
                let escaped = Self.likePattern(search)
                request = request.filter(
                    Column("title").like(escaped, escape: "\\")
                        || Column("text").like(escaped, escape: "\\")
                        || Column("ocrText").like(escaped, escape: "\\")
                )
            }
            if let limit { request = request.limit(limit) }
            return try request.fetchAll(db)
        }) ?? []
    }

    func setOCRText(_ text: String, forClipID id: Int64) throws {
        try dbQueue.write { db in
            guard var item = try ClipItem.fetchOne(db, key: id) else { return }
            item.ocrText = text
            item.contentBytes = Self.payloadBytes(item)
            try ensureCapacityForItem(item, replacing: id, in: db)
            try item.update(db)
            try trim(db)
        }
        notifyChange()
    }

    func setPinned(id: Int64, pinned: Bool) throws {
        try dbQueue.write { db in
            if pinned, let item = try ClipItem.fetchOne(db, key: id) {
                try ensureCapacityForItem(item, replacing: item.isPinned ? id : nil, in: db)
            }
            try db.execute(
                sql: "UPDATE clip SET isPinned = ?, pinnedAt = ? WHERE id = ?",
                arguments: [pinned, pinned ? Date() : nil, id]
            )
        }
        notifyChange()
    }

    func removeClip(id: Int64) throws -> RemovedClip? { try remove(id: id) }

    func remove(id: Int64) throws -> RemovedClip? {
        let removed = try dbQueue.write { db -> RemovedClip? in
            guard let item = try ClipItem.fetchOne(db, key: id) else { return nil }
            try ClipItem.deleteOne(db, key: id)
            return RemovedClip(item: item)
        }
        if removed != nil { notifyChange() }
        return removed
    }

    func restoreClip(_ removed: RemovedClip) throws { try restore(removed) }

    func restore(_ removed: RemovedClip) throws {
        var item = removed.item
        try dbQueue.write { db in
            try ensureCapacityForItem(item, replacing: item.isPinned ? item.id : nil, in: db)
            try item.insert(db, onConflict: .replace)
            try trim(db)
        }
        notifyChange()
    }

    func delete(id: Int64) { _ = try? remove(id: id) }

    func clearHistory(includePinned: Bool = false) throws { try clearAll(includePinned: includePinned) }

    func clearAll(includePinned: Bool = false) throws {
        try dbQueue.write { db in
            if includePinned {
                try ClipItem.deleteAll(db)
            } else {
                try db.execute(sql: "DELETE FROM clip WHERE isPinned = 0")
            }
        }
        notifyChange()
    }

    func clearAll() { try? clearAll(includePinned: true) }

    func vacuum() throws {
        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
            try db.execute(sql: "VACUUM")
        }
    }

    func trimToLimits() throws {
        try dbQueue.write { db in try trim(db) }
        notifyChange()
    }

    var count: Int {
        (try? dbQueue.read { db in try ClipItem.fetchCount(db) }) ?? 0
    }

    // MARK: - Snippets

    func snippetFolders() throws -> [SnippetFolder] {
        try dbQueue.read { db in
            try SnippetFolder.order(Column("sortIndex"), Column("id")).fetchAll(db)
        }
    }

    func snippets(inFolder folderID: Int64) -> [Snippet] {
        (try? dbQueue.read { db in
            try Snippet.filter(Column("folderID") == folderID)
                .order(Column("sortIndex"), Column("id")).fetchAll(db)
        }) ?? []
    }

    func allSnippets(search: String? = nil, pinnedOnly: Bool = false) throws -> [Snippet] {
        try dbQueue.read { db in
            var sql = "SELECT s.* FROM snippet s"
            var conditions: [String] = []
            var arguments = StatementArguments()
            if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let match = Self.ftsMatch(search) {
                    sql += " JOIN snippetSearch ON snippetSearch.rowid = s.id"
                    conditions.append("snippetSearch MATCH ?")
                    arguments += [match]
                } else {
                    conditions.append("""
                        (s.title LIKE ? ESCAPE '\\' OR s.content LIKE ? ESCAPE '\\'
                         OR s.keyword LIKE ? ESCAPE '\\')
                        """)
                    let pattern = Self.likePattern(search)
                    arguments += [pattern, pattern, pattern]
                }
            }
            if pinnedOnly { conditions.append("s.isPinned = 1") }
            if !conditions.isEmpty { sql += " WHERE " + conditions.joined(separator: " AND ") }
            if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sql += """
                     ORDER BY
                        CASE WHEN lower(COALESCE(s.keyword, '')) = lower(?) THEN 0 ELSE 1 END,
                        s.isPinned DESC, s.lastUsedAt DESC, s.updatedAt DESC, s.id DESC
                    """
                arguments += [search]
            } else {
                sql += " ORDER BY s.isPinned DESC, s.lastUsedAt DESC, s.updatedAt DESC, s.id DESC"
            }
            return try Snippet.fetchAll(db, sql: sql, arguments: arguments)
        }
    }

    @discardableResult
    func addFolder(title: String) throws -> SnippetFolder? {
        let folder = try dbQueue.write { db -> SnippetFolder in
            let maxIndex = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sortIndex), -1) FROM snippetFolder") ?? -1
            var folder = SnippetFolder(title: title, sortIndex: maxIndex + 1)
            try folder.insert(db)
            return folder
        }
        notifyChange()
        return folder
    }

    @discardableResult
    func addSnippet(
        folderID: Int64?,
        title: String,
        content: String,
        keyword: String? = nil
    ) throws -> Snippet? {
        let snippet = try dbQueue.write { db -> Snippet in
            let maxIndex = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sortIndex), -1) FROM snippet WHERE folderID IS ?",
                arguments: [folderID]
            ) ?? -1
            var snippet = Snippet(
                folderID: folderID,
                title: title,
                content: content,
                sortIndex: maxIndex + 1,
                keyword: Self.normalizedKeyword(keyword)
            )
            try snippet.insert(db)
            return snippet
        }
        notifyChange()
        return snippet
    }

    func update(_ folder: SnippetFolder) {
        _ = try? dbQueue.write { db in try folder.update(db) }
        notifyChange()
    }

    func update(_ snippet: Snippet) throws {
        var snippet = snippet
        snippet.keyword = Self.normalizedKeyword(snippet.keyword)
        snippet.updatedAt = Date()
        try dbQueue.write { db in try snippet.update(db) }
        notifyChange()
    }

    func setSnippetPinned(id: Int64, pinned: Bool) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE snippet SET isPinned = ?, updatedAt = ? WHERE id = ?",
                arguments: [pinned, Date(), id]
            )
        }
        notifyChange()
    }

    func markSnippetUsed(id: Int64) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE snippet SET useCount = useCount + 1, lastUsedAt = ? WHERE id = ?",
                arguments: [Date(), id]
            )
        }
    }

    func deleteFolder(id: Int64) {
        _ = try? dbQueue.write { db in try SnippetFolder.deleteOne(db, key: id) }
        notifyChange()
    }

    func removeSnippet(id: Int64) throws -> RemovedSnippet? {
        let removed = try dbQueue.write { db -> RemovedSnippet? in
            guard let item = try Snippet.fetchOne(db, key: id) else { return nil }
            try Snippet.deleteOne(db, key: id)
            return RemovedSnippet(item: item)
        }
        if removed != nil { notifyChange() }
        return removed
    }

    func restoreSnippet(_ removed: RemovedSnippet) throws {
        var item = removed.item
        try dbQueue.write { db in
            if let folderID = item.folderID,
               try SnippetFolder.fetchOne(db, key: folderID) == nil {
                item.folderID = nil
            }
            try item.insert(db)
        }
        notifyChange()
    }

    func deleteSnippet(id: Int64) throws {
        _ = try removeSnippet(id: id)
    }

    func installStarterSnippetsIfNeeded(force: Bool = false) throws {
        guard installStarterContent else { return }
        try dbQueue.write { db in
            let installed = try String.fetchOne(
                db,
                sql: "SELECT value FROM appMetadata WHERE key = 'starterSnippetsInstalled'"
            ) == "1"
            guard force || !installed else { return }

            let russian = Locale.preferredLanguages.first?.lowercased().hasPrefix("ru") == true
            let folderTitle = russian ? "Быстрые ответы" : "Quick replies"
            var folder = try SnippetFolder.filter(Column("title") == folderTitle).fetchOne(db)
            if folder == nil {
                let maxIndex = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sortIndex), -1) FROM snippetFolder") ?? -1
                var created = SnippetFolder(title: folderTitle, sortIndex: maxIndex + 1)
                try created.insert(db)
                folder = created
            }

            let examples: [(String, String, String)] = russian ? [
                ("Приветствие", ";hello", "Здравствуйте!"),
                ("Спасибо", ";thanks", "Спасибо!"),
                ("Получено", ";received", "Получил. Вернусь с ответом."),
                ("Напишу позже", ";later", "Сейчас не могу ответить. Напишу позже."),
                ("Сегодня", ";date", "{date}"),
                ("Текущее время", ";time", "{time}")
            ] : [
                ("Greeting", ";hello", "Hello!"),
                ("Thanks", ";thanks", "Thank you!"),
                ("Received", ";received", "Got it. I’ll get back to you."),
                ("Reply later", ";later", "I can’t reply right now. I’ll follow up later."),
                ("Today", ";date", "{date}"),
                ("Current time", ";time", "{time}")
            ]

            for (index, example) in examples.enumerated() {
                let exists = try Int.fetchOne(
                    db,
                    sql: "SELECT 1 FROM snippet WHERE lower(keyword) = lower(?) LIMIT 1",
                    arguments: [example.1]
                ) != nil
                guard !exists else { continue }
                var snippet = Snippet(
                    folderID: folder?.id,
                    title: example.0,
                    content: example.2,
                    sortIndex: index,
                    keyword: example.1
                )
                try snippet.insert(db)
            }
            try db.execute(
                sql: "INSERT OR REPLACE INTO appMetadata(key, value) VALUES ('starterSnippetsInstalled', '1')"
            )
        }
        notifyChange()
    }

    // MARK: - Internals

    private func trim(_ db: Database) throws {
        let limit = max(10, Settings.historyLimit)
        let unpinned = try Row.fetchAll(
            db,
            sql: "SELECT id, contentBytes FROM clip WHERE isPinned = 0 ORDER BY createdAt DESC, id DESC"
        )
        if unpinned.count > limit {
            let ids: [Int64] = unpinned.dropFirst(limit).map { $0["id"] }
            if !ids.isEmpty {
                try db.execute(
                    sql: "DELETE FROM clip WHERE id IN (\(ids.map { _ in "?" }.joined(separator: ",")))",
                    arguments: StatementArguments(ids)
                )
            }
        }

        var total = try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(contentBytes), 0) FROM clip") ?? 0
        if total > Self.maximumStorageBytes {
            let oldest = try Row.fetchAll(
                db,
                sql: "SELECT id, contentBytes FROM clip WHERE isPinned = 0 ORDER BY createdAt ASC, id ASC"
            )
            for row in oldest where total > Self.maximumStorageBytes {
                let id: Int64 = row["id"]
                let bytes: Int64 = row["contentBytes"]
                try db.execute(sql: "DELETE FROM clip WHERE id = ?", arguments: [id])
                total -= bytes
            }
        }
    }

    private func ensureCapacityForItem(
        _ item: ClipItem,
        replacing replacedID: Int64?,
        in db: Database
    ) throws {
        var sql = "SELECT COALESCE(SUM(contentBytes), 0) FROM clip WHERE isPinned = 1"
        var arguments = StatementArguments()
        if let replacedID {
            sql += " AND id != ?"
            arguments += [replacedID]
        }
        let pinnedBytes = try Int64.fetchOne(db, sql: sql, arguments: arguments) ?? 0
        guard pinnedBytes + item.contentBytes <= Self.maximumStorageBytes else {
            throw StorageCapacityError.pinnedItemsUseAllAvailableSpace
        }
    }

    private func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .neClipStorageDidChange, object: self)
        }
    }

    private static func summary(from row: Row) -> ClipSummary? {
        let kindValue: String = row["kind"]
        guard let kind = ClipKind(rawValue: kindValue) else { return nil }
        return ClipSummary(
            id: row["id"],
            kind: kind,
            title: row["title"],
            text: row["text"],
            thumbnail: row["thumbnail"],
            appBundleID: row["appBundleID"],
            createdAt: row["createdAt"],
            isPinned: row["isPinned"]
        )
    }

    private static func payloadBytes(_ item: ClipItem) -> Int64 {
        Int64(
            (item.text?.utf8.count ?? 0)
                + (item.ocrText?.utf8.count ?? 0)
                + (item.data?.count ?? 0)
                + (item.rtf?.count ?? 0)
                + (item.thumbnail?.count ?? 0)
        )
    }

    private static func normalizedKeyword(_ keyword: String?) -> String? {
        guard let value = keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value.hasPrefix(";") ? value : ";" + value
    }

    private static func hash(for item: ClipItem) -> String? {
        let payload: Data?
        switch item.kind {
        case .text, .file:
            payload = item.text.map { Data($0.utf8) }
        case .image:
            payload = item.data
        }
        guard let payload else { return nil }
        return SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
    }

    private static func ftsMatch(_ query: String) -> String? {
        let tokens = query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return nil }
        return tokens.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }
            .joined(separator: " AND ")
    }

    private static func likePattern(_ query: String) -> String {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }
}
