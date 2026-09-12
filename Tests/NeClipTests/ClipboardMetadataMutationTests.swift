import Foundation
import GRDB
import XCTest
@testable import NeClip

final class ClipboardMetadataMutationTests: XCTestCase {
    func testPinDoesNotRebindOriginalPayloadColumns() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("neclip-metadata-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("fixture.sqlite").path
        var initial: Storage? = try Storage(path: path, installStarterContent: false)
        let id = try XCTUnwrap(initial?.insert(ClipItem(
            kind: .image, title: "Large image",
            data: Data(repeating: 7, count: 1_024 * 1_024), createdAt: Date()
        )))
        initial = nil
        // A regression to whole-record update must fail even when all original
        // values are equal; comparing only the final payload would miss it.
        try DatabaseQueue(path: path).write { db in
            try db.execute(sql: """
                CREATE TRIGGER protect_original_payload
                BEFORE UPDATE OF text, data, rtf ON clip
                BEGIN SELECT RAISE(ABORT, 'Metadata update rebound original payload'); END
                """)
        }
        let storage = try Storage(path: path, installStarterContent: false)
        try storage.setPinned(id: id, pinned: true)
        try storage.setPinned(id: id, pinned: false)
        XCTAssertEqual(try storage.fetchClip(id: id)?.data?.count, 1_024 * 1_024)
    }

    func testPinCapacityCheckUsesStoredByteAccountingAndRollsBack() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let pinnedID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Pinned", text: "sentinel", createdAt: Date(),
            contentBytes: Storage.maximumStorageBytes - 4, isPinned: true
        )))
        let otherID = try XCTUnwrap(storage.insert(ClipItem(
            kind: .image, title: "Other", data: Data([1]), createdAt: Date(),
            contentBytes: 4
        )))
        try storage.setPinned(id: otherID, pinned: true)
        try storage.setPinned(id: otherID, pinned: true)
        XCTAssertThrowsError(try storage.insert(ClipItem(
            kind: .text, title: "Overflow", text: "x", createdAt: Date(), contentBytes: 1
        ))) { error in
            XCTAssertEqual(error as? StorageCapacityError, .pinnedItemsUseAllAvailableSpace)
        }
        XCTAssertNil(try storage.fetchClip(id: otherID)?.ocrText)
        XCTAssertEqual(try storage.fetchClip(id: otherID)?.contentBytes, 4)
        XCTAssertEqual(try storage.fetchClip(id: pinnedID)?.contentBytes, Storage.maximumStorageBytes - 4)
    }
}
