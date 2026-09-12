import Foundation
import XCTest
@testable import NeClip

final class ClipboardCaptureFastPathTests: XCTestCase {
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
