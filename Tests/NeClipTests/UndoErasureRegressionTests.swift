import Foundation
import GRDB
import XCTest
@testable import NeClip

final class UndoErasureRegressionTests: XCTestCase {
    func testQueuedClipUndoCannotRestoreContentAfterFullErasure() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Private clip", text: "Erased content", createdAt: Date()
        )))
        let removed = try XCTUnwrap(storage.removeClip(id: id))
        let queue = DispatchQueue(label: "test.undo.clip")
        let release = DispatchSemaphore(value: 0)
        let finished = expectation(description: "queued clip undo rejected")
        queue.async {
            guard release.wait(timeout: .now() + 5) == .success else {
                XCTFail("Test gate timed out"); finished.fulfill(); return
            }
            do {
                try storage.restoreClip(removed)
                XCTFail("An undo queued before full erasure must not restore a clip")
            } catch {
                XCTAssertEqual(error as? UndoRestorationError, .invalidatedByErasure)
            }
            finished.fulfill()
        }
        try storage.deleteAllUserData()
        release.signal()
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(storage.count, 0)
    }

    func testQueuedSnippetUndoCannotRestoreContentAfterFullErasure() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Private snippet", content: "Erased content")?.id)
        let removed = try XCTUnwrap(storage.removeSnippet(id: id))
        let queue = DispatchQueue(label: "test.undo.snippet")
        let release = DispatchSemaphore(value: 0)
        let finished = expectation(description: "queued snippet undo rejected")
        queue.async {
            guard release.wait(timeout: .now() + 5) == .success else {
                XCTFail("Test gate timed out"); finished.fulfill(); return
            }
            do {
                try storage.restoreSnippet(removed)
                XCTFail("An undo queued before full erasure must not restore a snippet")
            } catch {
                XCTAssertEqual(error as? UndoRestorationError, .invalidatedByErasure)
            }
            finished.fulfill()
        }
        try storage.deleteAllUserData()
        release.signal()
        wait(for: [finished], timeout: 5)
        XCTAssertTrue(try storage.allSnippets().isEmpty)
    }

    func testOrdinaryUndoStillWorksForItemsRemovedAfterErasure() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        try storage.deleteAllUserData()
        let clipID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Fresh clip", text: "New content", createdAt: Date()
        )))
        let snippetID = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Fresh snippet", content: "New content")?.id)
        let clip = try XCTUnwrap(storage.removeClip(id: clipID))
        let snippet = try XCTUnwrap(storage.removeSnippet(id: snippetID))
        try storage.restoreClip(clip)
        try storage.restoreSnippet(snippet)
        XCTAssertEqual(try storage.fetchClip(id: clipID)?.text, "New content")
        XCTAssertEqual(try storage.fetchSnippet(id: snippetID)?.content, "New content")
    }

    func testLateMenuCompletionTokensBecomeInvalidBeforeErasureReturns() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let clipID = try XCTUnwrap(storage.insert(ClipItem(kind: .text, title: "Clip", text: "Body", createdAt: Date())))
        let snippetID = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "Snippet", content: "Body")?.id)
        let clip = try XCTUnwrap(storage.removeClip(id: clipID))
        let snippet = try XCTUnwrap(storage.removeSnippet(id: snippetID))
        XCTAssertTrue(storage.isUndoCurrent(clip.undoGeneration))
        XCTAssertTrue(storage.isUndoCurrent(snippet.undoGeneration))
        try storage.deleteAllUserData()
        // Same predicate used by both late delete and failed-undo completions.
        XCTAssertFalse(storage.isUndoCurrent(clip.undoGeneration))
        XCTAssertFalse(storage.isUndoCurrent(snippet.undoGeneration))
    }

    func testUndoTokensCannotCrossStorageInstances() throws {
        let first = try Storage(inMemory: true, installStarterContent: false)
        let other = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(first.addSnippet(folderID: nil, title: "Private", content: "Body")?.id)
        let removed = try XCTUnwrap(first.removeSnippet(id: id))
        XCTAssertFalse(other.isUndoCurrent(removed.undoGeneration))
        XCTAssertThrowsError(try other.restoreSnippet(removed)) {
            XCTAssertEqual($0 as? UndoRestorationError, .invalidatedByErasure)
        }
        XCTAssertTrue(try other.allSnippets().isEmpty)
    }

    func testFailedErasureRollsBackWithoutInvalidatingOrdinaryUndo() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("NeClip-undo-erasure-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("test.sqlite").path
        let storage = try Storage(path: path, installStarterContent: false)
        let fixture = try DatabaseQueue(path: path)
        let id = try XCTUnwrap(storage.insert(ClipItem(kind: .text, title: "Undo", text: "Removed", createdAt: Date())))
        let removed = try XCTUnwrap(storage.removeClip(id: id))
        _ = try storage.insert(ClipItem(kind: .text, title: "Keep", text: "Remaining", createdAt: Date()))
        try fixture.write { db in
            try db.execute(sql: """
                CREATE TRIGGER test_refuse_erasure BEFORE DELETE ON clip
                BEGIN SELECT RAISE(ABORT, 'test erasure failure'); END
                """)
        }
        XCTAssertThrowsError(try storage.deleteAllUserData())
        XCTAssertEqual(storage.count, 1)
        XCTAssertTrue(storage.isUndoCurrent(removed.undoGeneration))
        try fixture.write { db in try db.execute(sql: "DROP TRIGGER test_refuse_erasure") }
        try storage.restoreClip(removed)
        XCTAssertEqual(storage.count, 2)
        XCTAssertEqual(try storage.fetchClip(id: id)?.text, "Removed")
    }
}
