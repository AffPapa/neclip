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
    let appBundleID: String?
    let createdAt: Date
    let isPinned: Bool
}

struct RemovedClip: Sendable {
    let item: ClipItem
    let undoGeneration: UUID
}

struct RemovedSnippet: Sendable {
    let item: Snippet
    let undoGeneration: UUID
}

enum UndoRestorationError: LocalizedError, Equatable {
    case invalidatedByErasure

    var errorDescription: String? { "После полной очистки восстановление недоступно" }
}

enum StorageCapacityError: LocalizedError, Equatable {
    case pinnedItemsUseAllAvailableSpace

    var errorDescription: String? {
        "Закреплённые элементы заняли весь лимит хранилища"
    }
}

enum ClipStorageError: LocalizedError, Equatable {
    case clipNotFound
    case emptyText
    case snippetRequiresText

    var errorDescription: String? {
        switch self {
        case .clipNotFound:
            "Элемент истории больше не существует"
        case .emptyText:
            "Текст не может быть пустым"
        case .snippetRequiresText:
            "Сниппет можно создать только из текста"
        }
    }
}

enum SnippetStorageError: LocalizedError, Equatable {
    case emptyFolderTitle
    case folderTitleTooLong
    case folderNotFound
    case snippetNotFound
    case snippetTitleTooLong
    case snippetKeywordTooLong
    case snippetContentTooLarge
    case keywordAlreadyExists

    var errorDescription: String? {
        switch self {
        case .emptyFolderTitle:
            "Название папки не может быть пустым"
        case .folderTitleTooLong:
            "Название папки не должно быть длиннее 200 символов"
        case .folderNotFound:
            "Папка больше не существует"
        case .snippetNotFound:
            "Сниппет больше не существует"
        case .snippetTitleTooLong:
            "Название сниппета не должно быть длиннее 200 символов"
        case .snippetKeywordTooLong:
            "Ключ сниппета не должен быть длиннее 100 символов"
        case .snippetContentTooLarge:
            "Текст сниппета не должен быть больше 2 МБ"
        case .keywordAlreadyExists:
            "Этот ключ поиска уже занят другим сниппетом. Выберите другой ключ."
        }
    }

    /// Database errors can embed statements and user-provided text. Only our
    /// explicitly authored domain messages may be displayed in the editor.
    static func userFacingMessage(for error: Error, fallback: String) -> String {
        (error as? SnippetStorageError)?.errorDescription ?? fallback
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

/// Lightweight metadata used by menus, search and the editor sidebar. Full
/// snippet bodies are fetched only when the user opens or pastes one item.
struct SnippetSummary: Codable, FetchableRecord, Identifiable, Hashable, Sendable {
    let id: Int64?
    let folderID: Int64?
    let folderTitle: String?
    let title: String
    let contentPreview: String
    let contentIsTruncated: Bool
    let sortIndex: Int
    let keyword: String?
    let isPinned: Bool

    init(snippet: Snippet, previewLimit: Int = Storage.snippetPreviewCharacterLimit, folderTitle: String? = nil) {
        id = snippet.id
        folderID = snippet.folderID
        self.folderTitle = folderTitle
        title = snippet.title
        let preview = snippet.content.prefix(max(0, previewLimit))
        contentPreview = String(preview)
        // The slice already records where we stopped. Counting every grapheme
        // of a multi-megabyte body would defeat this lightweight projection.
        contentIsTruncated = preview.endIndex != snippet.content.endIndex
        sortIndex = snippet.sortIndex
        keyword = snippet.keyword
        isPinned = snippet.isPinned
    }
}

/// A deliberately bounded projection for the native menu.
struct SnippetMenuSnapshot: Sendable {
    let folders: [SnippetFolder]
    let snippets: [SnippetSummary]
    let hasMore: Bool
}

struct SnippetTransferDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let snippets: [SnippetTransferRecord]

    init(version: Int = currentVersion, snippets: [SnippetTransferRecord]) {
        self.version = version
        self.snippets = snippets
    }
}

struct SnippetTransferRecord: Codable, Equatable, Sendable {
    let folder: String?
    let title: String
    let content: String
    let keyword: String?
    let isPinned: Bool
}

enum SnippetTransferError: LocalizedError, Equatable {
    case unsupportedVersion
    case fileTooLarge
    case tooManySnippets
    case invalidSnippet
    case exportTooLarge

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "Эта версия файла сниппетов не поддерживается"
        case .fileTooLarge: "Файл сниппетов слишком большой"
        case .tooManySnippets: "В файле слишком много сниппетов"
        case .invalidSnippet: "В файле есть некорректный сниппет"
        case .exportTooLarge: "Библиотека превышает лимит переносимого файла: 16 МБ или 5000 сниппетов. Экспорт не создан; исходные сниппеты сохранены."
        }
    }
}

extension Notification.Name {
    static let neClipStorageDidChange = Notification.Name("org.affpapa.neclip.storageDidChange")
}

enum StorageChangeDomain: String, Sendable {
    case clips
    case snippets
    case all

    static let notificationKey = "domain"

    var includesSnippets: Bool { self == .snippets || self == .all }

    static func from(_ notification: Notification) -> StorageChangeDomain? {
        guard let rawValue = notification.userInfo?[notificationKey] as? String else { return nil }
        return StorageChangeDomain(rawValue: rawValue)
    }
}

final class Storage: @unchecked Sendable {
    static let maximumStorageBytes: Int64 = 250 * 1024 * 1024
    static let maximumSnippetImportBytes = 16 * 1024 * 1024
    static let maximumSnippetTitleCharacters = 200
    static let maximumSnippetKeywordCharacters = 100
    static let snippetPreviewCharacterLimit = 280

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
    // Access only inside dbQueue. Tokens belong to this storage instance and
    // cannot survive full erasure, even in a queued undo or late UI completion.
    private var undoGeneration = UUID()

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
                let dataDirectoryOverride = RuntimeIdentity.previewDataDirectory
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
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o700],
                    ofItemAtPath: directory.path
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
        // Thumbnails were generated for a preview toggle that never had a
        // renderer. They are derived data, so remove them once and reclaim the
        // disk/quota cost while preserving every original image.
        migrator.registerMigration("v5-remove-unused-thumbnails") { db in
            try db.execute(sql: """
                UPDATE clip
                SET thumbnail = NULL,
                    contentBytes = COALESCE(length(CAST(text AS BLOB)), 0)
                        + COALESCE(length(CAST(ocrText AS BLOB)), 0)
                        + COALESCE(length(data), 0)
                        + COALESCE(length(rtf), 0)
                WHERE thumbnail IS NOT NULL
                """)
        }
        // Metadata-only changes (pin/use counters/timestamps) must not delete
        // and reinsert complete FTS bodies. Large snippets can be up to 2 MB,
        // so guarding these triggers materially reduces every snippet paste.
        migrator.registerMigration("v6-guard-fts-update-triggers") { db in
            try db.execute(sql: """
                DROP TRIGGER IF EXISTS clipSearch_au;
                CREATE TRIGGER clipSearch_au
                AFTER UPDATE OF title, text, ocrText, appBundleID ON clip
                WHEN old.title IS NOT new.title
                    OR old.text IS NOT new.text
                    OR old.ocrText IS NOT new.ocrText
                    OR old.appBundleID IS NOT new.appBundleID
                BEGIN
                    INSERT INTO clipSearch(clipSearch, rowid, title, text, ocrText, appBundleID)
                    VALUES ('delete', old.id, old.title, old.text, old.ocrText, old.appBundleID);
                    INSERT INTO clipSearch(rowid, title, text, ocrText, appBundleID)
                    VALUES (new.id, new.title, new.text, new.ocrText, new.appBundleID);
                END;

                DROP TRIGGER IF EXISTS snippetSearch_au;
                CREATE TRIGGER snippetSearch_au
                AFTER UPDATE OF title, content, keyword ON snippet
                WHEN old.title IS NOT new.title
                    OR old.content IS NOT new.content
                    OR old.keyword IS NOT new.keyword
                BEGIN
                    INSERT INTO snippetSearch(snippetSearch, rowid, title, content, keyword)
                    VALUES ('delete', old.id, old.title, old.content, old.keyword);
                    INSERT INTO snippetSearch(rowid, title, content, keyword)
                    VALUES (new.id, new.title, new.content, new.keyword);
                END;
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
                            .filter(
                                Column("contentHash") == nil
                                    && Column("kind") == item.kind.rawValue
                                    && Column("text") == text
                            )
                            .fetchOne(db)
                    }
                case .image:
                    if let data = item.data {
                        existing = try ClipItem
                            .filter(
                                Column("contentHash") == nil
                                    && Column("kind") == item.kind.rawValue
                                    && Column("data") == data
                            )
                            .fetchOne(db)
                    }
                }
            }
            if var existing {
                existing.title = item.title
                existing.text = item.text ?? existing.text
                existing.data = item.data ?? existing.data
                // Formatting belongs to the latest clipboard write. Retaining
                // an older RTF representation would make a later plain-text
                // copy paste with stale styling.
                existing.rtf = item.rtf
                existing.appBundleID = item.appBundleID
                existing.createdAt = item.createdAt
                existing.contentBytes = Self.payloadBytes(existing)
                existing.contentHash = item.contentHash
                try ensureCapacityForBytes(existing.contentBytes, replacing: existing.id, in: db)
                try existing.update(db)
                try trim(db)
                return existing.id
            }
            try ensureCapacityForBytes(item.contentBytes, replacing: nil, in: db)
            try item.insert(db)
            try trim(db)
            return item.id
        }
        notifyChange(.clips)
        return id
    }

    /// Appends text to the newest unpinned text record in one transaction.
    /// Rich text is intentionally dropped because two independent RTF payloads
    /// cannot be concatenated without changing their document semantics.
    func appendToLatestUnpinnedText(
        _ nextText: String,
        appBundleID: String?,
        createdAt: Date,
        maximumBytes: Int
    ) throws -> AppendTextResult {
        let result = try dbQueue.write { db -> AppendTextResult in
            guard var latest = try ClipItem
                .filter(Column("kind") == ClipKind.text.rawValue && Column("isPinned") == false)
                .order(Column("createdAt").desc, Column("id").desc)
                .fetchOne(db),
                let latestID = latest.id,
                let existingText = latest.text else {
                return .noEligibleItem
            }

            let merged = ClipboardTextMerge.join(existingText, nextText)
            let mergedBytes = merged.utf8.count
            guard mergedBytes <= max(1, maximumBytes) else {
                return .combinedValueTooLarge
            }

            latest.title = ClipboardTextMerge.title(for: merged)
            latest.text = merged
            latest.data = nil
            latest.rtf = nil
            latest.ocrText = nil
            latest.appBundleID = appBundleID
            latest.createdAt = createdAt
            latest.contentBytes = Int64(mergedBytes)
            latest.contentHash = Self.hash(for: latest)

            if let duplicate = try ClipItem
                .filter(
                    Column("kind") == ClipKind.text.rawValue
                        && Column("contentHash") == latest.contentHash
                        && Column("id") != latestID
                )
                .order(Column("createdAt").desc, Column("id").desc)
                .fetchOne(db), let duplicateID = duplicate.id {
                var replacement = latest
                replacement.id = duplicateID
                replacement.isPinned = duplicate.isPinned
                replacement.pinnedAt = duplicate.pinnedAt
                try ensureCapacityForBytes(replacement.contentBytes, replacing: duplicateID, in: db)
                try replacement.update(db)
                try db.execute(sql: "DELETE FROM clip WHERE id = ?", arguments: [latestID])
                try trim(db)
                return .appended(duplicateID)
            }

            try ensureCapacityForBytes(latest.contentBytes, replacing: latestID, in: db)
            try latest.update(db)
            try trim(db)
            return .appended(latestID)
        }
        if case .appended = result { notifyChange(.clips) }
        return result
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

    /// Structured search keeps all database work on lightweight summary rows.
    /// Semantic categories are filtered after SQL because SQLite deliberately
    /// has no custom regex or application code loaded into the database.
    func searchSummaries(
        query: ClipboardSearchQuery,
        limit: Int = 20
    ) throws -> [ClipSummary] {
        let exact = try searchCandidates(
            query: query,
            includeTerms: true,
            requestedMatches: limit
        )
        if !exact.isEmpty || query.terms.isEmpty {
            return Array(exact.prefix(limit))
        }

        // Fuzzy ranking stays bounded to 300 lightweight summaries, but a
        // semantic filter may page past many unrelated recent rows to collect
        // those candidates. This keeps old links/emails/colors/code searchable.
        let candidates = try searchCandidates(
            query: query,
            includeTerms: false,
            requestedMatches: 300
        )
        return ClipboardFuzzySearch.ranked(candidates, query: query.terms, limit: limit)
    }

    private func searchCandidates(
        query: ClipboardSearchQuery,
        includeTerms: Bool,
        requestedMatches: Int
    ) throws -> [ClipSummary] {
        guard query.needsPostFiltering else {
            return try fetchSummaries(
                search: includeTerms ? query.terms : nil,
                query: query,
                limit: requestedMatches
            )
        }

        let batchSize = max(200, min(1_000, requestedMatches * 10))
        var offset = 0
        var matches: [ClipSummary] = []
        while matches.count < requestedMatches {
            let batch = try fetchSummaries(
                search: includeTerms ? query.terms : nil,
                query: query,
                limit: batchSize,
                offset: offset
            )
            matches.append(contentsOf: batch.filter {
                SmartClipClassifier.matches($0, category: query.smartCategory)
            })
            guard batch.count == batchSize else { break }
            offset += batch.count
        }
        return Array(matches.prefix(requestedMatches))
    }

    func recentSummaries(
        limit: Int = 60,
        search: String? = nil,
        pinnedOnly: Bool = false,
        unpinnedOnly: Bool = false,
        offset: Int = 0
    ) throws -> [ClipSummary] {
        try fetchSummaries(
            search: search, pinnedOnly: pinnedOnly, unpinnedOnly: unpinnedOnly,
            limit: limit, offset: offset
        )
    }

    /// Physical recency order for sequential paste. Pins affect menu grouping,
    /// not the order in which the user originally copied values.
    func recentClipIDs(limit: Int = 50) throws -> [Int64] {
        try dbQueue.read { db in
            try Int64.fetchAll(
                db,
                sql: "SELECT id FROM clip ORDER BY createdAt DESC, id DESC LIMIT ?",
                arguments: [max(1, min(limit, 200))]
            )
        }
    }

    private func fetchSummaries(
        search: String?,
        query: ClipboardSearchQuery? = nil,
        pinnedOnly: Bool = false,
        unpinnedOnly: Bool = false,
        limit: Int,
        offset: Int = 0
    ) throws -> [ClipSummary] {
        try dbQueue.read { db in
            var sql = """
                SELECT c.id, c.kind, c.title,
                       substr(COALESCE(c.text, c.ocrText, ''), 1, 280) AS text,
                       c.appBundleID, c.createdAt, c.isPinned
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
                    let pattern = Self.likePattern(search)
                    conditions.append("""
                        (c.title LIKE ? ESCAPE '\\' OR c.text LIKE ? ESCAPE '\\'
                         OR c.ocrText LIKE ? ESCAPE '\\' OR c.appBundleID LIKE ? ESCAPE '\\')
                        """)
                    arguments += [pattern, pattern, pattern, pattern]
                }
            }
            if let kind = query?.kind {
                conditions.append("c.kind = ?")
                arguments += [kind.rawValue]
            }
            if let app = query?.appFragment {
                conditions.append("lower(COALESCE(c.appBundleID, '')) LIKE ? ESCAPE '\\'")
                arguments += [Self.likePattern(app.lowercased())]
            }
            if let since = query?.since {
                conditions.append("c.createdAt >= ?")
                arguments += [since]
            }
            switch query?.pinFilter {
            case .pinned?: conditions.append("c.isPinned = 1")
            case .history?: conditions.append("c.isPinned = 0")
            case nil: break
            }
            if pinnedOnly { conditions.append("c.isPinned = 1") }
            if unpinnedOnly { conditions.append("c.isPinned = 0") }
            if !conditions.isEmpty {
                sql += " WHERE " + conditions.joined(separator: " AND ")
            }
            sql += " ORDER BY c.isPinned DESC, c.pinnedAt DESC, c.createdAt DESC LIMIT ? OFFSET ?"
            arguments += [max(1, limit), max(0, offset)]
            let rows = try Row.fetchAll(db, sql: sql, arguments: arguments)
            return rows.compactMap(Self.summary(from:))
        }
    }

    func fetchClip(id: Int64) throws -> ClipItem? {
        try dbQueue.read { db in try ClipItem.fetchOne(db, key: id) }
    }

    // OCR-only paste must not materialize the original image or RTF BLOBs.
    static let ocrTextProjectionSQL = """
        SELECT title, ocrText, createdAt FROM clip WHERE id = ? AND kind = 'image'
        """

    func fetchOCRTextItem(id: Int64) throws -> ClipItem? {
        try dbQueue.read { db in
            guard let row = try Row.fetchOne(db, sql: Self.ocrTextProjectionSQL, arguments: [id]),
                  let recognized: String = row["ocrText"] else { return nil }
            let text = recognized.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return ClipItem(kind: .text, title: row["title"], text: text, createdAt: row["createdAt"])
        }
    }

    func setOCRText(_ text: String, forClipID id: Int64) throws {
        try dbQueue.write { db in
            // Recount the original representations without materializing them
            // in Swift. Replacing OCR must not fetch/rebind a large image BLOB.
            guard let contentBytes = try Int64.fetchOne(db, sql: """
                SELECT COALESCE(length(CAST(text AS BLOB)), 0)
                     + COALESCE(length(data), 0)
                     + COALESCE(length(rtf), 0) + ?
                FROM clip WHERE id = ?
                """, arguments: [text.utf8.count, id]) else { return }
            try ensureCapacityForBytes(contentBytes, replacing: id, in: db)
            try db.execute(
                sql: "UPDATE clip SET ocrText = ?, contentBytes = ? WHERE id = ?",
                arguments: [text, contentBytes, id]
            )
            try trim(db)
        }
        notifyChange(.clips)
    }

    func setPinned(id: Int64, pinned: Bool) throws {
        try dbQueue.write { db in
            if pinned, let row = try Row.fetchOne(
                db, sql: "SELECT isPinned, contentBytes FROM clip WHERE id = ?", arguments: [id]
            ) {
                let isPinned: Bool = row["isPinned"]
                try ensureCapacityForBytes(
                    row["contentBytes"], replacing: isPinned ? id : nil, in: db
                )
            }
            try db.execute(
                sql: "UPDATE clip SET isPinned = ?, pinnedAt = ? WHERE id = ?",
                arguments: [pinned, pinned ? Date() : nil, id]
            )
        }
        notifyChange(.clips)
    }

    /// Renames any clip and optionally replaces the payload of a text clip.
    /// Editing text intentionally drops stale RTF and re-hashes the payload.
    @discardableResult
    func updateClip(id: Int64, title: String, text: String?) throws -> ClipItem {
        let updated = try dbQueue.write { db -> ClipItem in
            guard var item = try ClipItem.fetchOne(db, key: id) else {
                throw ClipStorageError.clipNotFound
            }
            let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            if item.kind == .text, let text {
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ClipStorageError.emptyText
                }
                item.text = text
                item.rtf = nil
                item.contentHash = Self.hash(for: item)
            }
            if !normalizedTitle.isEmpty {
                item.title = normalizedTitle
            } else if let text = item.text {
                item.title = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
            }
            item.contentBytes = Self.payloadBytes(item)
            try ensureCapacityForBytes(item.contentBytes, replacing: id, in: db)
            try item.update(db)
            try trim(db)
            return item
        }
        notifyChange(.clips)
        return updated
    }

    func removeClip(id: Int64) throws -> RemovedClip? {
        let removed = try dbQueue.write { db -> RemovedClip? in
            guard let item = try ClipItem.fetchOne(db, key: id) else { return nil }
            try ClipItem.deleteOne(db, key: id)
            return RemovedClip(item: item, undoGeneration: undoGeneration)
        }
        if removed != nil { notifyChange(.clips) }
        return removed
    }

    func restoreClip(_ removed: RemovedClip) throws {
        var item = removed.item
        try dbQueue.write { db in
            guard removed.undoGeneration == undoGeneration else {
                throw UndoRestorationError.invalidatedByErasure
            }
            try ensureCapacityForBytes(item.contentBytes, replacing: item.isPinned ? item.id : nil, in: db)
            try item.insert(db, onConflict: .replace)
            try trim(db)
        }
        notifyChange(.clips)
    }

    /// Deletes history in one transaction. `createdAfter` supports privacy
    /// cleanup of recent values while ordinary cleanup still protects pins.
    @discardableResult
    func clearHistory(includePinned: Bool = false, createdAfter: Date? = nil) throws -> Int {
        let removed = try dbQueue.write { db -> Int in
            var conditions: [String] = []
            var arguments = StatementArguments()
            if !includePinned { conditions.append("isPinned = 0") }
            if let createdAfter {
                conditions.append("createdAt >= ?")
                arguments += [createdAfter]
            }
            let suffix = conditions.isEmpty ? "" : " WHERE " + conditions.joined(separator: " AND ")
            try db.execute(sql: "DELETE FROM clip" + suffix, arguments: arguments)
            return db.changesCount
        }
        if removed > 0 { notifyChange(.clips) }
        return removed
    }

    /// Erases every user-created record in one transaction. Keeping this
    /// atomic avoids partially cleared state and one transaction per snippet.
    func deleteAllUserData() throws {
        try dbQueue.writeWithoutTransaction { db in
            try db.inTransaction {
                try ClipItem.deleteAll(db)
                try Snippet.deleteAll(db)
                try SnippetFolder.deleteAll(db)
                return .commit
            }
            // Commit succeeded, and we still own the serialized database queue:
            // a queued restore cannot slip between erasure and invalidation.
            undoGeneration = UUID()
        }
        notifyChange(.all)
    }

    /// Also guards late menu completions; failure to read means fail closed.
    func isUndoCurrent(_ generation: UUID) -> Bool {
        (try? dbQueue.read { _ in undoGeneration == generation }) ?? false
    }

    func vacuum() throws {
        try dbQueue.writeWithoutTransaction { db in
            try db.execute(sql: "PRAGMA wal_checkpoint(TRUNCATE)")
            try db.execute(sql: "VACUUM")
        }
    }

    func trimToLimits() throws {
        try dbQueue.write { db in try trim(db) }
        notifyChange(.clips)
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

    func snippetCount(inFolder folderID: Int64) throws -> Int {
        try dbQueue.read { db in
            try Snippet.filter(Column("folderID") == folderID).fetchCount(db)
        }
    }

    func snippets(inFolder folderID: Int64) -> [Snippet] {
        (try? dbQueue.read { db in
            try Snippet.filter(Column("folderID") == folderID)
                .order(Column("sortIndex"), Column("id")).fetchAll(db)
        }) ?? []
    }

    func allSnippets(
        search: String? = nil,
        pinnedOnly: Bool = false,
        limit: Int? = nil
    ) throws -> [Snippet] {
        try dbQueue.read { db in
            let tail = try Self.snippetQueryTail(database: db, search: search, pinnedOnly: pinnedOnly, limit: limit)
            return try Snippet.fetchAll(db, sql: "SELECT s.* FROM snippet s" + tail.sql, arguments: tail.arguments)
        }
    }

    func snippetSummaries(
        search: String? = nil,
        pinnedOnly: Bool = false,
        limit: Int? = nil
    ) throws -> [SnippetSummary] {
        try dbQueue.read { db in
            try Self.fetchSnippetSummaries(
                database: db,
                search: search,
                pinnedOnly: pinnedOnly,
                limit: limit
            )
        }
    }

    func fetchSnippet(id: Int64) throws -> Snippet? {
        try dbQueue.read { db in try Snippet.fetchOne(db, key: id) }
    }

    /// Loads only the snippets that can reasonably be browsed in a native
    /// menu, plus the folders needed to present those visible rows.
    func menuSnippetSnapshot(limit requestedLimit: Int = 200) throws -> SnippetMenuSnapshot {
        let limit = max(1, min(requestedLimit, 500))
        return try dbQueue.read { db in
            let fetched = try Self.fetchSnippetSummaries(
                database: db,
                search: nil,
                pinnedOnly: false,
                limit: limit + 1
            )
            let snippets = Array(fetched.prefix(limit))
            let folderIDs = Set(snippets.compactMap(\.folderID))
            let folders = folderIDs.isEmpty
                ? []
                : try SnippetFolder
                    .filter(keys: Array(folderIDs))
                    .order(Column("sortIndex"), Column("id"))
                    .fetchAll(db)
            return SnippetMenuSnapshot(
                folders: folders,
                snippets: snippets,
                hasMore: fetched.count > limit
            )
        }
    }

    @discardableResult
    func addFolder(title: String) throws -> SnippetFolder? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw SnippetStorageError.emptyFolderTitle }
        guard title.count <= Self.maximumSnippetTitleCharacters else {
            throw SnippetStorageError.folderTitleTooLong
        }
        let folder = try dbQueue.write { db -> SnippetFolder in
            let maxIndex = try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sortIndex), -1) FROM snippetFolder") ?? -1
            var folder = SnippetFolder(title: title, sortIndex: maxIndex + 1)
            try folder.insert(db)
            return folder
        }
        notifyChange(.snippets)
        return folder
    }

    @discardableResult
    func addSnippet(
        folderID: Int64?,
        title: String,
        content: String,
        keyword: String? = nil
    ) throws -> Snippet? {
        let fields = try Self.validatedSnippetFields(
            title: title,
            content: content,
            keyword: keyword
        )
        let snippet = try dbQueue.write { db -> Snippet in
            try Self.insertSnippet(folderID: folderID, fields: fields, database: db)
        }
        notifyChange(.snippets)
        return snippet
    }

    /// Reading and creating share one transaction so full erasure cannot fall
    /// between them and resurrect clipboard content as a new snippet.
    @discardableResult
    func saveClipAsSnippet(id: Int64) throws -> Snippet {
        let snippet = try dbQueue.write { db -> Snippet in
            guard let row = try Row.fetchOne(
                db, sql: "SELECT kind, title, text FROM clip WHERE id = ?", arguments: [id]
            ) else { throw ClipStorageError.clipNotFound }
            let kind: String = row["kind"]
            guard kind == ClipKind.text.rawValue,
                  let content: String = row["text"], !content.isEmpty else {
                throw ClipStorageError.snippetRequiresText
            }
            let title: String = row["title"]
            let fields = try Self.validatedSnippetFields(
                title: String(title.prefix(60)), content: content, keyword: nil
            )
            return try Self.insertSnippet(folderID: nil, fields: fields, database: db)
        }
        notifyChange(.snippets)
        return snippet
    }

    @discardableResult
    func update(_ folder: SnippetFolder) throws -> SnippetFolder {
        guard let id = folder.id else { throw SnippetStorageError.folderNotFound }
        let title = folder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw SnippetStorageError.emptyFolderTitle }
        guard title.count <= Self.maximumSnippetTitleCharacters else {
            throw SnippetStorageError.folderTitleTooLong
        }
        let updated = try dbQueue.write { db -> SnippetFolder in
            guard var stored = try SnippetFolder.fetchOne(db, key: id) else {
                throw SnippetStorageError.folderNotFound
            }
            stored.title = title
            stored.sortIndex = folder.sortIndex
            try stored.update(db)
            return stored
        }
        notifyChange(.snippets)
        return updated
    }

    @discardableResult
    func update(_ snippet: Snippet) throws -> Snippet {
        var snippet = snippet
        let fields = try Self.validatedSnippetFields(
            title: snippet.title,
            content: snippet.content,
            keyword: snippet.keyword
        )
        snippet.title = fields.title
        snippet.content = fields.content
        snippet.keyword = fields.keyword
        snippet.updatedAt = Date()
        let updated = try dbQueue.write { db -> Snippet in
            guard let id = snippet.id,
                  let stored = try Snippet.fetchOne(db, key: id) else {
                throw SnippetStorageError.snippetNotFound
            }
            if let folderID = snippet.folderID,
               try SnippetFolder.fetchOne(db, key: folderID) == nil {
                throw SnippetStorageError.folderNotFound
            }
            try Self.validateUniqueSnippetKeyword(snippet.keyword, excluding: id, database: db)
            if stored.folderID != snippet.folderID {
                snippet.sortIndex = try Self.nextSnippetSortIndex(
                    inFolder: snippet.folderID,
                    database: db
                )
            }
            try db.execute(
                sql: """
                    UPDATE snippet
                    SET folderID = ?, title = ?, content = ?, sortIndex = ?,
                        keyword = ?, isPinned = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [
                    snippet.folderID, snippet.title, snippet.content, snippet.sortIndex,
                    snippet.keyword, snippet.isPinned, snippet.updatedAt, id
                ]
            )
            guard let updated = try Snippet.fetchOne(db, key: id) else {
                throw SnippetStorageError.snippetNotFound
            }
            return updated
        }
        notifyChange(.snippets)
        return updated
    }

    @discardableResult
    func moveSnippet(id: Int64, toFolderID folderID: Int64?) throws -> Snippet {
        let moved = try dbQueue.write { db -> Snippet in
            guard var snippet = try Snippet.fetchOne(db, key: id) else {
                throw SnippetStorageError.snippetNotFound
            }
            if let folderID,
               try SnippetFolder.fetchOne(db, key: folderID) == nil {
                throw SnippetStorageError.folderNotFound
            }
            guard snippet.folderID != folderID else { return snippet }
            snippet.folderID = folderID
            snippet.sortIndex = try Self.nextSnippetSortIndex(inFolder: folderID, database: db)
            snippet.updatedAt = Date()
            try snippet.update(db)
            return snippet
        }
        notifyChange(.snippets)
        return moved
    }

    func setSnippetPinned(id: Int64, pinned: Bool) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE snippet SET isPinned = ?, updatedAt = ? WHERE id = ?",
                arguments: [pinned, Date(), id]
            )
        }
        notifyChange(.snippets)
    }

    func markSnippetUsed(id: Int64) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE snippet SET useCount = useCount + 1, lastUsedAt = ? WHERE id = ?",
                arguments: [Date(), id]
            )
        }
        notifyChange(.snippets)
    }

    /// Duplicates editable content atomically. A search key must remain unique,
    /// while usage history belongs to the original rather than its copy.
    func duplicateSnippet(id: Int64) throws -> Snippet {
        let duplicate = try dbQueue.write { db -> Snippet in
            guard let original = try Snippet.fetchOne(db, key: id) else {
                throw SnippetStorageError.snippetNotFound
            }
            let suffix = " — копия"
            let title = String(original.title.prefix(Self.maximumSnippetTitleCharacters - suffix.count)) + suffix
            var copy = Snippet(
                folderID: original.folderID,
                title: title,
                content: original.content,
                sortIndex: try Self.nextSnippetSortIndex(inFolder: original.folderID, database: db),
                keyword: nil,
                isPinned: original.isPinned
            )
            try copy.insert(db)
            return copy
        }
        notifyChange(.snippets)
        return duplicate
    }

    func deleteFolder(id: Int64) throws {
        try dbQueue.write { db in
            guard try SnippetFolder.deleteOne(db, key: id) else {
                throw SnippetStorageError.folderNotFound
            }
        }
        notifyChange(.snippets)
    }

    func removeSnippet(id: Int64) throws -> RemovedSnippet? {
        let removed = try dbQueue.write { db -> RemovedSnippet? in
            guard let item = try Snippet.fetchOne(db, key: id) else { return nil }
            try Snippet.deleteOne(db, key: id)
            return RemovedSnippet(item: item, undoGeneration: undoGeneration)
        }
        if removed != nil { notifyChange(.snippets) }
        return removed
    }

    func restoreSnippet(_ removed: RemovedSnippet) throws {
        var item = removed.item
        try dbQueue.write { db in
            guard removed.undoGeneration == undoGeneration else {
                throw UndoRestorationError.invalidatedByErasure
            }
            if let folderID = item.folderID,
               try SnippetFolder.fetchOne(db, key: folderID) == nil {
                item.folderID = nil
            }
            try item.insert(db)
        }
        notifyChange(.snippets)
    }

    func deleteSnippet(id: Int64) throws {
        guard try removeSnippet(id: id) != nil else {
            throw SnippetStorageError.snippetNotFound
        }
    }

    /// Portable, versioned JSON. History and usage metadata are intentionally
    /// excluded so sharing a snippet file cannot leak clipboard activity.
    func exportSnippetData() throws -> Data {
        let document = try dbQueue.read { db -> SnippetTransferDocument in
            guard try Snippet.fetchCount(db) <= 5_000 else {
                throw SnippetTransferError.exportTooLarge
            }
            let payloadBytes = try Int64.fetchOne(db, sql: """
                SELECT COALESCE(SUM(
                    length(CAST(title AS BLOB)) + length(CAST(content AS BLOB))
                    + COALESCE(length(CAST(keyword AS BLOB)), 0)
                ), 0) FROM snippet
                """) ?? 0
            guard payloadBytes <= Int64(Self.maximumSnippetImportBytes) else {
                throw SnippetTransferError.exportTooLarge
            }
            let folders = try SnippetFolder.order(Column("sortIndex"), Column("id")).fetchAll(db)
            let folderTitles = Dictionary(uniqueKeysWithValues: folders.compactMap { folder in
                folder.id.map { ($0, folder.title) }
            })
            let snippets = try Snippet.order(Column("folderID"), Column("sortIndex"), Column("id")).fetchAll(db)
            return SnippetTransferDocument(snippets: snippets.map { snippet in
                SnippetTransferRecord(
                    folder: snippet.folderID.flatMap { folderTitles[$0] },
                    title: snippet.title,
                    content: snippet.content,
                    keyword: snippet.keyword,
                    isPinned: snippet.isPinned
                )
            })
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(document)
        guard data.count <= Self.maximumSnippetImportBytes else {
            throw SnippetTransferError.exportTooLarge
        }
        return data
    }

    /// Merge-only import: existing folders are reused and exact duplicate
    /// snippets are skipped. The whole file commits atomically.
    @discardableResult
    func importSnippetData(_ data: Data) throws -> Int {
        guard !data.isEmpty, data.count <= Self.maximumSnippetImportBytes else {
            throw SnippetTransferError.fileTooLarge
        }
        let document = try JSONDecoder().decode(SnippetTransferDocument.self, from: data)
        guard document.version == SnippetTransferDocument.currentVersion else {
            throw SnippetTransferError.unsupportedVersion
        }
        guard document.snippets.count <= 5_000 else {
            throw SnippetTransferError.tooManySnippets
        }
        let validated = try document.snippets.map { record -> SnippetTransferRecord in
            let title = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let folder = record.folder?.trimmingCharacters(in: .whitespacesAndNewlines)
            let keyword = Self.normalizedKeyword(record.keyword)
            guard !title.isEmpty,
                  title.count <= Self.maximumSnippetTitleCharacters,
                  record.content.utf8.count <= ClipboardCapturePolicy.maxTextBytes,
                  (folder?.count ?? 0) <= Self.maximumSnippetTitleCharacters,
                  (keyword?.count ?? 0) <= Self.maximumSnippetKeywordCharacters else {
                throw SnippetTransferError.invalidSnippet
            }
            return SnippetTransferRecord(
                folder: folder.flatMap { $0.isEmpty ? nil : $0 },
                title: title,
                content: record.content,
                keyword: keyword,
                isPinned: record.isPinned
            )
        }

        let inserted = try dbQueue.write { db -> Int in
            var folderCache: [String: Int64] = [:]
            var inserted = 0
            for record in validated {
                let folderID: Int64?
                if let folderTitle = record.folder {
                    let cacheKey = folderTitle.lowercased()
                    if let cached = folderCache[cacheKey] {
                        folderID = cached
                    } else if let existing = try Int64.fetchOne(
                        db,
                        sql: "SELECT id FROM snippetFolder WHERE lower(title) = lower(?) ORDER BY id LIMIT 1",
                        arguments: [folderTitle]
                    ) {
                        folderCache[cacheKey] = existing
                        folderID = existing
                    } else {
                        let maxIndex = try Int.fetchOne(
                            db,
                            sql: "SELECT COALESCE(MAX(sortIndex), -1) FROM snippetFolder"
                        ) ?? -1
                        var folder = SnippetFolder(title: folderTitle, sortIndex: maxIndex + 1)
                        try folder.insert(db)
                        guard let createdID = folder.id else {
                            throw SnippetTransferError.invalidSnippet
                        }
                        folderCache[cacheKey] = createdID
                        folderID = createdID
                    }
                } else {
                    folderID = nil
                }

                let duplicate = try Bool.fetchOne(
                    db,
                    sql: """
                        SELECT EXISTS(
                            SELECT 1 FROM snippet
                            WHERE folderID IS ? AND title = ? AND content = ?
                              AND COALESCE(keyword, '') = COALESCE(?, '')
                        )
                        """,
                    arguments: [folderID, record.title, record.content, record.keyword]
                ) ?? false
                guard !duplicate else { continue }

                let sortIndex = try Self.nextSnippetSortIndex(inFolder: folderID, database: db)
                var snippet = Snippet(
                    folderID: folderID,
                    title: record.title,
                    content: record.content,
                    sortIndex: sortIndex,
                    keyword: record.keyword,
                    isPinned: record.isPinned
                )
                try snippet.insert(db)
                inserted += 1
            }
            return inserted
        }
        if inserted > 0 { notifyChange(.snippets) }
        return inserted
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
        notifyChange(.snippets)
    }

    // MARK: - Internals

    private static func insertSnippet(
        folderID: Int64?,
        fields: (title: String, content: String, keyword: String?),
        database db: Database
    ) throws -> Snippet {
        if let folderID, try SnippetFolder.fetchOne(db, key: folderID) == nil {
            throw SnippetStorageError.folderNotFound
        }
        try validateUniqueSnippetKeyword(fields.keyword, database: db)
        var snippet = Snippet(
            folderID: folderID, title: fields.title, content: fields.content,
            sortIndex: try nextSnippetSortIndex(inFolder: folderID, database: db),
            keyword: fields.keyword
        )
        try snippet.insert(db)
        return snippet
    }

    private static func validateUniqueSnippetKeyword(
        _ keyword: String?, excluding id: Int64? = nil, database db: Database
    ) throws {
        guard let keyword, !keyword.isEmpty else { return }
        // Use the same comparison as snippet_keyword_unique, inside the write
        // transaction; keep the unique index as the final integrity guard.
        let exists = try Bool.fetchOne(
            db,
            sql: "SELECT EXISTS(SELECT 1 FROM snippet WHERE lower(keyword) = lower(?) AND (? IS NULL OR id <> ?))",
            arguments: [keyword, id, id]
        ) ?? false
        if exists { throw SnippetStorageError.keywordAlreadyExists }
    }

    private static func validatedSnippetFields(
        title: String,
        content: String,
        keyword: String?
    ) throws -> (title: String, content: String, keyword: String?) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count <= maximumSnippetTitleCharacters else {
            throw SnippetStorageError.snippetTitleTooLong
        }
        let keyword = normalizedKeyword(keyword)
        guard (keyword?.count ?? 0) <= maximumSnippetKeywordCharacters else {
            throw SnippetStorageError.snippetKeywordTooLong
        }
        guard content.utf8.count <= ClipboardCapturePolicy.maxTextBytes else {
            throw SnippetStorageError.snippetContentTooLarge
        }
        return (title, content, keyword)
    }

    private static func fetchSnippetSummaries(
        database db: Database,
        search: String?,
        pinnedOnly: Bool,
        limit: Int?
    ) throws -> [SnippetSummary] {
        let sql = """
            SELECT s.id, s.folderID, f.title AS folderTitle, s.title,
                   substr(s.content, 1, \(snippetPreviewCharacterLimit)) AS contentPreview,
                   substr(s.content, \(snippetPreviewCharacterLimit + 1), 1) != '' AS contentIsTruncated,
                   s.sortIndex, s.keyword, s.isPinned
            FROM snippet s
            LEFT JOIN snippetFolder f ON f.id = s.folderID
            """
        let tail = try snippetQueryTail(database: db, search: search, pinnedOnly: pinnedOnly, limit: limit)
        return try SnippetSummary.fetchAll(db, sql: sql + tail.sql, arguments: tail.arguments)
    }

    private static func snippetQueryTail(
        database db: Database, search: String?, pinnedOnly: Bool, limit: Int?
    ) throws -> (sql: String, arguments: StatementArguments) {
        var sql = ""
        var conditions: [String] = []
        var arguments = StatementArguments()
        let trimmedSearch = search?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedSearch.isEmpty {
            try appendSnippetSearch(
                trimmedSearch, database: db, conditions: &conditions, arguments: &arguments
            )
        }
        if pinnedOnly { conditions.append("s.isPinned = 1") }
        if !conditions.isEmpty { sql += " WHERE " + conditions.joined(separator: " AND ") }
        if !trimmedSearch.isEmpty {
            sql += """
                 ORDER BY
                    CASE WHEN lower(COALESCE(s.keyword, '')) = lower(?) THEN 0 ELSE 1 END,
                    s.isPinned DESC, s.lastUsedAt DESC, s.updatedAt DESC, s.id DESC
                """
            arguments += [normalizedKeyword(trimmedSearch) ?? trimmedSearch]
        } else {
            sql += " ORDER BY s.isPinned DESC, s.lastUsedAt DESC, s.updatedAt DESC, s.id DESC"
        }
        if let limit {
            sql += " LIMIT ?"
            arguments += [max(1, limit)]
        }
        return (sql, arguments)
    }

    private static func appendSnippetSearch(
        _ search: String,
        database db: Database,
        conditions: inout [String],
        arguments: inout StatementArguments
    ) throws {
        let search = search.trimmingCharacters(in: .whitespacesAndNewlines)
        var alternatives: [String] = []
        if let match = ftsMatch(search) {
            alternatives.append("s.id IN (SELECT rowid FROM snippetSearch WHERE snippetSearch MATCH ?)")
            arguments += [match]
        } else {
            alternatives.append("""
                (s.title LIKE ? ESCAPE '\\' OR s.content LIKE ? ESCAPE '\\'
                 OR s.keyword LIKE ? ESCAPE '\\')
                """)
            let pattern = likePattern(search)
            arguments += [pattern, pattern, pattern]
        }
        // SQLite lower()/NOCASE handle ASCII only. Match user-facing folder
        // names in Swift so Russian and diacritic-insensitive queries work too.
        let folderIDs = try SnippetFolder.fetchAll(db).compactMap { folder -> Int64? in
            folder.title.range(of: search, options: [.caseInsensitive, .diacriticInsensitive]) == nil
                ? nil : folder.id
        }
        if !folderIDs.isEmpty {
            alternatives.append("s.folderID IN (\(Array(repeating: "?", count: folderIDs.count).joined(separator: ",")))")
            arguments += StatementArguments(folderIDs)
        }
        conditions.append("(" + alternatives.joined(separator: " OR ") + ")")
    }

    private func trim(_ db: Database) throws {
        let retentionDays = Settings.retentionDays
        if retentionDays > 0 {
            let cutoff = Date().addingTimeInterval(-TimeInterval(retentionDays) * 86_400)
            try db.execute(
                sql: "DELETE FROM clip WHERE isPinned = 0 AND createdAt < ?",
                arguments: [cutoff]
            )
        }
        let limit = max(10, Settings.historyLimit)
        try db.execute(
            sql: """
                DELETE FROM clip
                WHERE id IN (
                    SELECT id FROM clip
                    WHERE isPinned = 0
                    ORDER BY createdAt DESC, id DESC
                    LIMIT -1 OFFSET ?
                )
                """,
            arguments: [limit]
        )

        let total = try Int64.fetchOne(db, sql: "SELECT COALESCE(SUM(contentBytes), 0) FROM clip") ?? 0
        if total > Self.maximumStorageBytes {
            let bytesToRemove = total - Self.maximumStorageBytes
            try db.execute(
                sql: """
                    WITH ordered AS (
                        SELECT
                            id,
                            SUM(contentBytes) OVER (
                                ORDER BY createdAt ASC, id ASC
                                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                            ) AS removedBytes
                        FROM clip
                        WHERE isPinned = 0
                    ), boundary AS (
                        SELECT MIN(removedBytes) AS removedBytes
                        FROM ordered
                        WHERE removedBytes >= ?
                    )
                    DELETE FROM clip
                    WHERE id IN (
                        SELECT id
                        FROM ordered
                        WHERE removedBytes <= COALESCE(
                            (SELECT removedBytes FROM boundary),
                            9223372036854775807
                        )
                    )
                    """,
                arguments: [bytesToRemove]
            )
        }
    }

    private func ensureCapacityForBytes(
        _ contentBytes: Int64,
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
        guard pinnedBytes + contentBytes <= Self.maximumStorageBytes else {
            throw StorageCapacityError.pinnedItemsUseAllAvailableSpace
        }
    }

    private func notifyChange(_ domain: StorageChangeDomain) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .neClipStorageDidChange,
                object: self,
                userInfo: [StorageChangeDomain.notificationKey: domain.rawValue]
            )
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
        )
    }

    private static func normalizedKeyword(_ keyword: String?) -> String? {
        guard let value = keyword?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value.hasPrefix(";") ? value : ";" + value
    }

    private static func nextSnippetSortIndex(
        inFolder folderID: Int64?,
        database db: Database
    ) throws -> Int {
        let maxIndex = try Int.fetchOne(
            db,
            sql: "SELECT COALESCE(MAX(sortIndex), -1) FROM snippet WHERE folderID IS ?",
            arguments: [folderID]
        ) ?? -1
        return maxIndex + 1
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
