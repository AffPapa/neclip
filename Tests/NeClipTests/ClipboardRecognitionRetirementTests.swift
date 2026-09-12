import Foundation
import XCTest
@testable import NeClip

final class ClipboardRecognitionRetirementTests: XCTestCase {
    func testClipboardSourcesDoNotInvokeContentRecognition() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources/NeClip")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            XCTAssertNil(source.range(of: #"(?m)^\s*import\s+(Vision|CoreML|NaturalLanguage)\b"#,
                                      options: .regularExpression), file.lastPathComponent)
            XCTAssertFalse(source.contains("VNRecognizeTextRequest"), file.lastPathComponent)
            XCTAssertFalse(source.contains("OCRService.recognize"), file.lastPathComponent)
        }
    }

    func testRetiringRecognitionPreservesExistingImagesAndLegacyMetadata() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-legacy-image-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("fixture.sqlite").path
        let pixels = Data(repeating: 37, count: 4096)
        let legacyText = "Previously stored metadata Привет"
        let legacyID: Int64
        let newID: Int64
        do {
            let storage = try Storage(path: path, installStarterContent: false)
            legacyID = try XCTUnwrap(storage.insert(ClipItem(
                kind: .image, title: "Legacy image", data: pixels,
                ocrText: legacyText, createdAt: Date()
            )))
            newID = try XCTUnwrap(storage.insert(ClipItem(
                kind: .image, title: "New image", data: Data([1, 2, 3]), createdAt: Date()
            )))
        }
        let reopened = try Storage(path: path, installStarterContent: false)
        let legacy = try XCTUnwrap(reopened.fetchClip(id: legacyID))
        XCTAssertEqual(legacy.data, pixels)
        XCTAssertEqual(legacy.ocrText, legacyText)
        XCTAssertEqual(legacy.contentBytes, Int64(pixels.count + legacyText.utf8.count))
        let new = try XCTUnwrap(reopened.fetchClip(id: newID))
        XCTAssertEqual(new.data, Data([1, 2, 3]))
        XCTAssertNil(new.ocrText)
        XCTAssertEqual(reopened.count, 2)
    }
}
