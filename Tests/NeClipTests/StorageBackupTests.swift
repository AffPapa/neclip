import Foundation
import XCTest
@testable import NeClip

final class StorageBackupTests: XCTestCase {
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
}
