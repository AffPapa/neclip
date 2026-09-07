import CryptoKit
import Foundation
import GRDB
import XCTest
@testable import NeClip

final class HotPathOptimizationTests: XCTestCase {
    func testSHA256KnownVectors() {
        XCTAssertEqual(ContentDigest.sha256(Data()),
                       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        XCTAssertEqual(ContentDigest.sha256(Data("abc".utf8)),
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testHexadecimalPreservesAllBytesAndLeadingZeroes() {
        let bytes = Array(UInt8.min...UInt8.max)
        XCTAssertEqual(ContentDigest.hexadecimal(bytes),
                       bytes.map { String(format: "%02x", $0) }.joined())
        XCTAssertEqual(ContentDigest.hexadecimal([0, 1, 15, 16, 255]), "00010f10ff")
        XCTAssertEqual(ContentDigest.hexadecimal([UInt8]()), "")
        let unicode = Data("Привет 👩🏽‍💻e\u{301}\n".utf8)
        XCTAssertEqual(ContentDigest.sha256(unicode),
                       SHA256.hash(data: unicode).map { String(format: "%02x", $0) }.joined())
    }

    func testCaptureDigestAndStorageFallbackDeduplicateEveryKind() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let payload = Data("Synthetic Привет\n".utf8)
        let expected = ContentDigest.sha256(payload)
        for kind in [ClipKind.text, .file, .image] {
            var item = ClipItem(kind: kind, title: "Synthetic", createdAt: Date())
            if kind == .image { item.data = payload }
            else { item.text = String(decoding: payload, as: UTF8.self) }
            let originalID = try XCTUnwrap(storage.insert(item))
            XCTAssertEqual(try storage.fetchClip(id: originalID)?.contentHash, expected)
            item.contentHash = expected
            item.createdAt = Date().addingTimeInterval(1)
            XCTAssertEqual(try storage.insert(item), originalID)
        }
        XCTAssertEqual(try storage.summaries().count, 3, "Equal bytes in different kinds stay separate")
    }

    @MainActor
    func testFolderIndexAndMenuKeepStableTiesAfterEditingAndMoving() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folderID = try XCTUnwrap(storage.addFolder(title: "Folder")?.id)
        var first = try XCTUnwrap(storage.addSnippet(folderID: folderID, title: "First", content: "A"))
        var second = try XCTUnwrap(storage.addSnippet(folderID: folderID, title: "Second", content: "B"))
        let unfiled = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Unfiled", content: "C"))
        first.sortIndex = 5
        second.sortIndex = 5
        _ = try storage.update(second)
        _ = try storage.update(first)
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: second.id)
        XCTAssertEqual(model.snippets(in: folderID).map(\.id), [first.id, second.id])
        XCTAssertEqual(model.snippets(in: nil).map(\.id), [unfiled.id])
        XCTAssertEqual(try storage.menuSnippetSnapshot(limit: 2).snippets.map(\.id), [first.id, second.id])
        XCTAssertTrue(try storage.menuSnippetSnapshot(limit: 2).hasMore)

        model.editorContent = "Saved draft"
        model.editorChanged()
        XCTAssertTrue(model.flushPendingSave())
        XCTAssertEqual(model.snippets(in: folderID).map(\.id), [first.id, second.id])
        _ = try storage.moveSnippet(id: XCTUnwrap(second.id), toFolderID: nil)
        model.reload()
        XCTAssertEqual(model.snippets(in: folderID).map(\.id), [first.id])
        XCTAssertEqual(model.snippets(in: nil).map(\.id), [unfiled.id, second.id])
        try storage.deleteAllUserData()
        model.reload()
        XCTAssertTrue(model.snippets(in: folderID).isEmpty)
        XCTAssertTrue(model.snippets(in: nil).isEmpty)
    }

    @MainActor
    func testOrphanFolderMetadataKeepsPreviousIndexAndMenuFallbackOrder() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("neclip-index-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("synthetic.sqlite").path
        let storage = try Storage(path: path, installStarterContent: false)
        let folderID = try XCTUnwrap(storage.addFolder(title: "Old folder")?.id)
        let orphan = try XCTUnwrap(storage.addSnippet(folderID: folderID, title: "Orphan", content: "A"))
        let unfiled = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Unfiled", content: "B"))
        // A disposable legacy/corruption fixture only; ordinary storage enforces
        // referential integrity. Preserve how existing orphan metadata is grouped.
        var configuration = Configuration()
        configuration.foreignKeysEnabled = false
        let fixture = try DatabaseQueue(path: path, configuration: configuration)
        try fixture.write { db in
            try db.execute(sql: "DELETE FROM snippetFolder WHERE id = ?", arguments: [folderID])
        }
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: unfiled.id)
        XCTAssertEqual(model.snippets(in: folderID).map(\.id), [orphan.id])
        XCTAssertEqual(model.snippets(in: nil).map(\.id), [unfiled.id])
        let snapshot = try storage.menuSnippetSnapshot()
        XCTAssertTrue(snapshot.folders.isEmpty)
        // Both entries go to the menu's unfiled fallback, retaining SQL sortIndex/ID.
        XCTAssertEqual(snapshot.snippets.map(\.id), [orphan.id, unfiled.id])
        XCTAssertEqual(snapshot.snippets.map(\.id), snapshot.snippets.sorted(by: SnippetMenuOrder.lessThan).map(\.id))
    }
}
