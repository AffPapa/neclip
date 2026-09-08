import Foundation
import GRDB
import XCTest
@testable import NeClip

final class ClipboardCaptureFastPathTests: XCTestCase {
    func testOCRPasteReadsCompleteTextAndPreservesOriginalPayload() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let image = Data(repeating: 37, count: 10 * 1_024 * 1_024)
        let rtf = Data([1, 2, 3])
        let recognized = String(repeating: "Полный распознанный текст é 🐗\n", count: 64)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .image, title: "Image title", text: "Not the OCR field",
            data: image, rtf: rtf, ocrText: "  \n" + recognized + " \t",
            appBundleID: "test.source", createdAt: date
        )))
        let projected = try XCTUnwrap(storage.fetchOCRTextItem(id: id))
        XCTAssertEqual(projected.kind, .text)
        XCTAssertEqual(projected.title, "Image title")
        XCTAssertEqual(projected.createdAt, date)
        XCTAssertEqual(projected.text, recognized.trimmingCharacters(in: .whitespacesAndNewlines))
        XCTAssertGreaterThan(try XCTUnwrap(projected.text).count, Storage.snippetPreviewCharacterLimit)
        XCTAssertNil(projected.data)
        XCTAssertNil(projected.rtf)
        XCTAssertNil(projected.ocrText)
        let unchanged = try XCTUnwrap(storage.fetchClip(id: id))
        XCTAssertEqual(unchanged.data, image)
        XCTAssertEqual(unchanged.rtf, rtf)
        XCTAssertEqual(unchanged.ocrText, "  \n" + recognized + " \t")
    }

    func testOCRProjectionHasOnlyRequiredColumnsAndDoesNotNeedPayloadSchema() throws {
        let database = try DatabaseQueue()
        try database.write { db in
            // The exact production query must work even when data/rtf/text
            // columns do not exist. Selecting a whole ClipItem would fail this
            // projection contract (the selected column list is checked too).
            try db.execute(sql: """
                CREATE TABLE clip (id INTEGER PRIMARY KEY, kind TEXT, title TEXT, ocrText TEXT, createdAt REAL);
                INSERT INTO clip VALUES (1, 'image', 'Title', 'OCR', 1700000000);
                """)
            let row = try XCTUnwrap(Row.fetchOne(db, sql: Storage.ocrTextProjectionSQL, arguments: [1]))
            XCTAssertEqual(Array(row.columnNames), ["title", "ocrText", "createdAt"])
            XCTAssertEqual(row["ocrText"] as String, "OCR")
        }
    }

    func testOCRProjectionRejectsMissingEmptyAndNonImageRecords() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        XCTAssertNil(try storage.fetchOCRTextItem(id: Int64.max))
        for (index, recognized) in ([nil, "", " \t\n"] as [String?]).enumerated() {
            let id = try XCTUnwrap(storage.insert(ClipItem(
                kind: .image, title: "Image", data: Data([UInt8(index)]), ocrText: recognized, createdAt: Date()
            )))
            XCTAssertNil(try storage.fetchOCRTextItem(id: id))
        }
        for kind in [ClipKind.text, .file] {
            let id = try XCTUnwrap(storage.insert(ClipItem(
                kind: kind, title: "Not an image", text: "Body", ocrText: "OCR", createdAt: Date()
            )))
            XCTAssertNil(try storage.fetchOCRTextItem(id: id))
        }
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .image, title: "Removed", data: Data([9]), ocrText: "OCR", createdAt: Date()
        )))
        _ = try storage.removeClip(id: id)
        XCTAssertNil(try storage.fetchOCRTextItem(id: id))
    }

    func testAppendBranchesPrecedeStandalonePayloadConstruction() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Sources/NeClip/ClipboardMonitor.swift"), encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "private func processText("))
        let end = try XCTUnwrap(source.range(of: "private func processImage(", range: start.upperBound..<source.endIndex))
        let body = String(source[start.lowerBound..<end.lowerBound])
        let preflight = try XCTUnwrap(body.range(of: "ClipboardCapturePolicy.textRejectionReason("))
        let consume = try XCTUnwrap(body.range(of: "Settings.consumeAppendNextCopy()"))
        let append = try XCTUnwrap(body.range(of: "Storage.shared.appendToLatestUnpinnedText("))
        let success = try XCTUnwrap(body.range(of: "case .appended:"))
        let fallback = try XCTUnwrap(body.range(of: "case .noEligibleItem, .combinedValueTooLarge:"))
        let payload = try XCTUnwrap(body.range(of: "let textData = Data(text.utf8)"))
        XCTAssertLessThan(preflight.lowerBound, consume.lowerBound)
        XCTAssertLessThan(consume.lowerBound, append.lowerBound)
        XCTAssertLessThan(append.lowerBound, payload.lowerBound)
        XCTAssertTrue(body[success.upperBound..<fallback.lowerBound].contains("return"))
        XCTAssertTrue(body[fallback.upperBound..<payload.lowerBound].contains("break"))
        // Errors retain the previous capture-failure behavior, not a fallback
        // insert after a partially failed storage operation.
        let failure = try XCTUnwrap(body.range(of: "captureFailed(error)"))
        XCTAssertTrue(body[failure.upperBound..<payload.lowerBound].contains("return"))
        XCTAssertEqual(body.components(separatedBy: "insert(item)").count - 1, 1)
        let digest = try XCTUnwrap(body.range(of: "ContentDigest.sha256(textData)"))
        XCTAssertLessThan(payload.lowerBound, digest.lowerBound)
        XCTAssertEqual(body.components(separatedBy: "ContentDigest.sha256(textData)").count - 1, 1)
    }

    func testAppendFallbackResultsKeepExistingRecordUntouched() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(try storage.appendToLatestUnpinnedText(
            "new", appBundleID: "test.source", createdAt: date, maximumBytes: 8
        ), .noEligibleItem)
        XCTAssertEqual(storage.count, 0)
        let id = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text, title: "Previous", text: "previous", rtf: Data([1, 2]), createdAt: date
        )))
        XCTAssertEqual(try storage.appendToLatestUnpinnedText(
            "new", appBundleID: "test.source", createdAt: date, maximumBytes: 8
        ), .combinedValueTooLarge)
        let previous = try XCTUnwrap(storage.fetchClip(id: id))
        XCTAssertEqual(previous.text, "previous")
        XCTAssertEqual(previous.rtf, Data([1, 2]))
        XCTAssertEqual(storage.count, 1)
    }
}
