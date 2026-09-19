import Foundation
import GRDB
import XCTest
@testable import NeClip

final class StorageBackupTests: XCTestCase {
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
