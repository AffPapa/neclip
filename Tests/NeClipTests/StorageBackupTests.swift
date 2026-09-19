import Foundation
import GRDB
import XCTest
@testable import NeClip

final class StorageBackupTests: XCTestCase {
    func testTemporaryBackupIsPrivateBeforeSQLiteAndDoesNotReplaceCollisions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-private-backup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("snapshot.sqlite")
        try Storage.createPrivateBackupFile(at: target)
        let mode = try FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.intValue, 0o600)
        try Data("EXISTING_SENTINEL".utf8).write(to: target)
        XCTAssertThrowsError(try Storage.createPrivateBackupFile(at: target))
        XCTAssertEqual(try String(contentsOf: target, encoding: .utf8), "EXISTING_SENTINEL")
        let link = root.appendingPathComponent("link.sqlite")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        XCTAssertThrowsError(try Storage.createPrivateBackupFile(at: link))
    }

    func testBackupBudgetSeparatesSnippetsFromHistoryAndBoundsTotalWithoutOverflow() throws {
        var budget = Storage.BackupImportBudget()
        let mib: Int64 = 1024 * 1024
        try budget.include(bytes: 249 * mib, clipPayload: 249 * mib)
        try budget.include(bytes: 2 * mib)
        XCTAssertEqual(budget.totalBytes, 251 * mib)
        XCTAssertEqual(budget.clipBytes, 249 * mib)
        XCTAssertThrowsError(try budget.include(bytes: 2 * mib, clipPayload: 2 * mib))
        XCTAssertThrowsError(try budget.include(bytes: Int64.max))
        try budget.include(bytes: 249 * mib)
        XCTAssertEqual(budget.totalBytes, Storage.maximumBackupBytes)
        XCTAssertThrowsError(try budget.include(bytes: 1))
    }

    func testRestoreRejectsIncompatibleSchemaAndNeverCopiesExecutableObjects() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-schema-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let liveURL = root.appendingPathComponent("live.sqlite")
        let live = try Storage(path: liveURL.path, installStarterContent: false)
        let id = try XCTUnwrap(live.insert(ClipItem(kind: .text, title: "Keep", text: "SYNTHETIC_BODY", createdAt: Date())))
        let malformed = root.appendingPathComponent("malformed.sqlite")
        let bad = try DatabaseQueue(path: malformed.path)
        try bad.write { db in
            for name in ["clip", "snippet", "snippetFolder", "appMetadata"] {
                try db.execute(sql: "CREATE TABLE \(name)(id INTEGER)")
            }
        }
        XCTAssertThrowsError(try live.restoreDatabaseBackup(from: malformed))
        XCTAssertEqual(try live.fetchClip(id: id)?.text, "SYNTHETIC_BODY")

        let backup = root.appendingPathComponent("backup.sqlite")
        _ = try live.createDatabaseBackup(to: backup)
        let source = try DatabaseQueue(path: backup.path)
        try source.write { db in
            try db.execute(sql: """
                CREATE TABLE retained_secret(value TEXT);
                CREATE TRIGGER retain_deleted AFTER DELETE ON clip
                BEGIN INSERT INTO retained_secret VALUES (old.text); END;
                UPDATE clip SET contentBytes = -1, contentHash = 'forged';
                """)
        }
        _ = try live.restoreDatabaseBackup(from: backup)
        XCTAssertGreaterThan(try XCTUnwrap(live.fetchClip(id: id)?.contentBytes), 0)
        XCTAssertNotEqual(try live.fetchClip(id: id)?.contentHash, "forged")
        let inspection = try DatabaseQueue(path: liveURL.path)
        try inspection.read { db in
            XCTAssertEqual(try Int.fetchOne(db, sql: "SELECT count(*) FROM sqlite_master WHERE name IN ('retained_secret','retain_deleted')"), 0)
        }
        try live.deleteAllUserData()
        XCTAssertEqual(live.count, 0)
    }

    func testRestoreRejectsUnknownMigrationsGeneratedColumnsAndExtremeOrdering() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-restore-validation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let live = try Storage(inMemory: true, installStarterContent: false)
        _ = try live.insert(ClipItem(kind: .text, title: "Keep", text: "Keep", createdAt: Date()))
        for (index, sql) in [
            "INSERT INTO grdb_migrations VALUES ('future-unknown')",
            "ALTER TABLE clip ADD COLUMN surprise TEXT GENERATED ALWAYS AS (title) VIRTUAL",
            "INSERT INTO snippetFolder(id,title,sortIndex) VALUES (1,'Test',-9223372036854775808)"
        ].enumerated() {
            let url = root.appendingPathComponent("invalid-\(index).sqlite")
            _ = try live.createDatabaseBackup(to: url)
            let db = try DatabaseQueue(path: url.path)
            try db.write { try $0.execute(sql: sql) }
            XCTAssertThrowsError(try live.restoreDatabaseBackup(from: url))
            XCTAssertEqual(live.count, 1)
        }
    }

    func testRestoreSupportsKnownLegacyPrefixAndInvalidatesOldUndo() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-legacy-backup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let live = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(live.insert(ClipItem(kind: .text, title: "Keep", text: "Keep", createdAt: Date())))
        let backup = root.appendingPathComponent("legacy.sqlite")
        _ = try live.createDatabaseBackup(to: backup)
        let removed = try XCTUnwrap(live.removeClip(id: id))
        let source = try DatabaseQueue(path: backup.path)
        try source.write { db in
            try db.execute(sql: "DELETE FROM grdb_migrations WHERE identifier IN ('v7-retire-search','v8-retire-pins')")
            try db.execute(sql: "UPDATE clip SET isPinned = 1")
        }
        _ = try live.restoreDatabaseBackup(from: backup)
        XCTAssertFalse(live.isUndoCurrent(removed.undoGeneration))
        XCTAssertEqual(try live.fetchClip(id: id)?.isPinned, false)
    }

    func testBackupPreservesExistingFolderModeAndFailedPublicationPreservesOldFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-backup-publish-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
        let liveURL = root.appendingPathComponent("live.sqlite")
        let live = try Storage(path: liveURL.path, installStarterContent: false)
        let destination = root.appendingPathComponent("export.sqlite")
        _ = try live.createDatabaseBackup(to: destination)
        let bytes = try Data(contentsOf: destination)
        XCTAssertThrowsError(try Storage.publishBackup(root.appendingPathComponent("missing.sqlite"), to: destination))
        XCTAssertEqual(try Data(contentsOf: destination), bytes)
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: root.path)[.posixPermissions] as? NSNumber)?.intValue, 0o755)
        XCTAssertThrowsError(try live.createDatabaseBackup(to: liveURL))
        let replacement = try live.createDatabaseBackup(to: destination)
        // SQLite may update page-header counters between valid snapshots.
        // Byte identity matters on failed publication, not a successful export.
        XCTAssertEqual(replacement.sha256, ContentDigest.sha256(try Data(contentsOf: destination)))
    }

    func testDeleteAllUserDataRemovesManagedRestoreSnapshotsButPreservesUserExport() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-erase-backups-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let live = try Storage(path: root.appendingPathComponent("live.sqlite").path, installStarterContent: false)
        let clipID = try XCTUnwrap(live.insert(ClipItem(
            kind: .text, title: "Private clip", text: "ERASE_CLIP_SENTINEL", createdAt: Date()
        )))
        let snippetID = try XCTUnwrap(live.addSnippet(
            folderID: nil, title: "Private snippet", content: "ERASE_SNIPPET_SENTINEL"
        )?.id)
        // Keep an explicit export alongside the DB: cleanup must not remove it.
        let export = root.appendingPathComponent("user-export.sqlite")
        _ = try live.createDatabaseBackup(to: export)
        let exportedBytes = try Data(contentsOf: export)
        let exportedManifest = try Data(contentsOf: export.appendingPathExtension("json"))
        for _ in 0..<2 { _ = try live.restoreDatabaseBackup(from: export) }
        let snapshots = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("neclip-before-restore-") && $0.pathExtension == "sqlite" }
        XCTAssertEqual(snapshots.count, 2)
        for snapshot in snapshots {
            let copy = try Storage(path: snapshot.path, installStarterContent: false)
            XCTAssertEqual(try copy.fetchClip(id: clipID)?.text, "ERASE_CLIP_SENTINEL")
            XCTAssertEqual(try copy.fetchSnippet(id: snippetID)?.content, "ERASE_SNIPPET_SENTINEL")
        }

        try live.deleteAllUserData()
        try live.vacuum()

        XCTAssertEqual(live.count, 0)
        XCTAssertTrue(try live.allSnippets().isEmpty)
        XCTAssertTrue(try live.snippetFolders().isEmpty)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertFalse(remaining.contains { $0.hasPrefix("neclip-before-restore-") })
        XCTAssertEqual(try Data(contentsOf: export), exportedBytes)
        XCTAssertEqual(try Data(contentsOf: export.appendingPathExtension("json")), exportedManifest)
    }

    func testErasureRemovesOrphanSidecarsButPreservesUnrelatedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-erase-boundary-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("live", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let live = try Storage(path: directory.appendingPathComponent("live.sqlite").path, installStarterContent: false)
        let stem = "neclip-before-restore-\(UUID().uuidString).sqlite"
        let sidecars = [".json", "-wal", "-shm", "-journal"].map { directory.appendingPathComponent(stem + $0) }
        let preserved = [
            root.appendingPathComponent(stem),
            directory.appendingPathComponent("user-export.sqlite"),
            directory.appendingPathComponent("neclip-before-restore-manual.sqlite"),
            directory.appendingPathComponent(stem + ".user-copy"),
            directory.appendingPathComponent("other-" + stem)
        ]
        let bytes = Data("BOUNDARY_SENTINEL".utf8)
        for file in sidecars + preserved { try bytes.write(to: file) }

        try live.deleteAllUserData()

        for file in sidecars { XCTAssertFalse(FileManager.default.fileExists(atPath: file.path)) }
        for file in preserved { XCTAssertEqual(try Data(contentsOf: file), bytes) }
    }

    @MainActor
    func testPartialErasureDoesNotFollowSymlinksAndStillInvalidatesViewsAndUndo() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-erase-partial-\(UUID().uuidString)", isDirectory: true)
        let directory = root.appendingPathComponent("live", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let live = try Storage(path: directory.appendingPathComponent("live.sqlite").path, installStarterContent: false)
        let clipID = try XCTUnwrap(live.insert(ClipItem(kind: .text, title: "Private", text: "Body", createdAt: Date())))
        _ = try live.addSnippet(folderID: nil, title: "Private", content: "Body")
        let export = root.appendingPathComponent("export.sqlite")
        _ = try live.createDatabaseBackup(to: export)
        _ = try live.restoreDatabaseBackup(from: export)
        let removed = try XCTUnwrap(live.removeClip(id: clipID))
        let exportBytes = try Data(contentsOf: export)
        let link = directory.appendingPathComponent("neclip-before-restore-\(UUID().uuidString).sqlite")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: export)
        let obstacle = directory.appendingPathComponent("neclip-before-restore-\(UUID().uuidString).sqlite")
        try FileManager.default.createDirectory(at: obstacle, withIntermediateDirectories: false)
        let child = obstacle.appendingPathComponent("keep.txt")
        try Data("KEEP".utf8).write(to: child)

        // Drain earlier restore notifications before observing this erasure.
        let drained = expectation(description: "Earlier storage notifications drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 2)
        let changed = expectation(forNotification: .neClipStorageDidChange, object: live) {
            StorageChangeDomain.from($0) == .all
        }
        XCTAssertThrowsError(try live.deleteAllUserData()) {
            XCTAssertEqual($0 as? UserDataErasureError, .managedSnapshotsRemain)
        }
        wait(for: [changed], timeout: 2)
        XCTAssertFalse(live.isUndoCurrent(removed.undoGeneration))
        XCTAssertEqual(live.count, 0)
        XCTAssertTrue(try live.allSnippets().isEmpty)
        XCTAssertEqual(try Data(contentsOf: export), exportBytes)
        XCTAssertEqual(try Data(contentsOf: child), Data("KEEP".utf8))
        XCTAssertTrue(try link.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink == true)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("neclip-before-restore-") }
        XCTAssertEqual(Set(remaining), [link.lastPathComponent, obstacle.lastPathComponent])

        // Removing the test obstacles allows an ordinary retry to complete.
        try FileManager.default.removeItem(at: link)
        try FileManager.default.removeItem(at: obstacle)
        XCTAssertNoThrow(try live.deleteAllUserData())
    }

    func testFailedDatabaseErasurePreservesRestoreSnapshot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-erase-transaction-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let path = root.appendingPathComponent("live.sqlite").path
        let live = try Storage(path: path, installStarterContent: false)
        _ = try live.insert(ClipItem(kind: .text, title: "Keep", text: "KEEP", createdAt: Date()))
        let export = root.appendingPathComponent("export.sqlite")
        _ = try live.createDatabaseBackup(to: export)
        _ = try live.restoreDatabaseBackup(from: export)
        let snapshots = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("neclip-before-restore-") }
        XCTAssertFalse(snapshots.isEmpty)
        let originalBytes = try snapshots.map { try Data(contentsOf: $0) }
        let fixture = try DatabaseQueue(path: path)
        try fixture.write { db in
            try db.execute(sql: """
                CREATE TRIGGER test_refuse_erasure BEFORE DELETE ON clip
                BEGIN SELECT RAISE(ABORT, 'test erasure failure'); END
                """)
        }

        XCTAssertThrowsError(try live.deleteAllUserData()) {
            XCTAssertFalse($0 is UserDataErasureError)
        }
        XCTAssertEqual(live.count, 1)
        for (file, bytes) in zip(snapshots, originalBytes) { XCTAssertEqual(try Data(contentsOf: file), bytes) }
    }

    func testDatabaseBackupIsSQLiteSnapshotWithManifestAndPrivatePermissions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = try Storage(path: root.appendingPathComponent("live.sqlite").path, installStarterContent: false)
        _ = try storage.insert(ClipItem(kind: .text, title: "Title", text: "Body", rtf: Data([1, 2]), createdAt: Date()))
        let destination = root.appendingPathComponent("NeClip Backup.sqlite")
        let manifest = try storage.createDatabaseBackup(to: destination)

        XCTAssertEqual(manifest.clipCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.appendingPathExtension("json").path))
        let permissions = try FileManager.default.attributesOfItem(atPath: destination.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue ?? 0, 0o600)

        let reopened = try Storage(path: destination.path, installStarterContent: false)
        XCTAssertEqual(try reopened.fetchClip(id: 1)?.text, "Body")
    }

    func testRestoreValidatesBeforeReplacingLiveDatabase() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let live = try Storage(path: root.appendingPathComponent("live.sqlite").path, installStarterContent: false)
        let oldID = try XCTUnwrap(live.insert(ClipItem(kind: .text, title: "Old", text: "old", createdAt: Date())))
        let backup = root.appendingPathComponent("backup.sqlite")
        _ = try live.createDatabaseBackup(to: backup)
        _ = try live.insert(ClipItem(kind: .text, title: "New", text: "new", createdAt: Date()))
        XCTAssertNotNil(try live.fetchClip(id: oldID))
        XCTAssertEqual(live.count, 2)

        _ = try live.restoreDatabaseBackup(from: backup)
        XCTAssertEqual(live.count, 1)
        XCTAssertEqual(try live.fetchClip(id: oldID)?.text, "old")
        XCTAssertFalse(try live.searchClipSummaries(query: "new").contains { $0.title == "New" })
    }

    func testInvalidRestoreDoesNotChangeLiveData() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-invalid-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let live = try Storage(path: root.appendingPathComponent("live.sqlite").path, installStarterContent: false)
        _ = try live.insert(ClipItem(kind: .text, title: "Keep", text: "keep", createdAt: Date()))
        let invalid = root.appendingPathComponent("invalid.sqlite")
        try Data("not sqlite".utf8).write(to: invalid)
        XCTAssertThrowsError(try live.restoreDatabaseBackup(from: invalid))
        XCTAssertEqual(live.count, 1)
        XCTAssertEqual(try live.summaries(limit: 1).first?.title, "Keep")
    }

    func testRestoreRejectsSymbolicLinkBeforeOpeningSQLite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-symlink-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("target.sqlite")
        try Data("not sqlite".utf8).write(to: target)
        let link = root.appendingPathComponent("selected.sqlite")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertThrowsError(try Storage.validateRestoreInput(link)) { error in
            XCTAssertEqual(error as? DatabaseBackupError, .invalidDatabase)
        }
    }

    func testRestoreRejectsOversizedFileBeforeOpeningSQLite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-oversize-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let oversized = root.appendingPathComponent("oversized.sqlite")
        FileManager.default.createFile(atPath: oversized.path, contents: Data())
        let handle = try FileHandle(forWritingTo: oversized)
        try handle.truncate(atOffset: UInt64(Storage.maximumBackupBytes) + 1)
        try handle.close()

        XCTAssertThrowsError(try Storage.validateRestoreInput(oversized)) { error in
            XCTAssertEqual(error as? DatabaseBackupError, .backupTooLarge)
        }
    }
}
