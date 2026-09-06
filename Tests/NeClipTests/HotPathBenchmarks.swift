import Foundation
import XCTest
@testable import NeClip

/// Opt-in synthetic benchmark. Setup and full-payload verification are excluded
/// from timings; this never opens the user's database or pasteboard.
final class HotPathBenchmarks: XCTestCase {
    func testSyntheticMetadataAndEmptyRuleLatency() throws {
        guard ProcessInfo.processInfo.environment["NECLIP_RUN_HOT_PATH_BENCHMARKS"] == "1" else {
            throw XCTSkip("Set NECLIP_RUN_HOT_PATH_BENCHMARKS=1 for synthetic latency measurements")
        }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("neclip-hot-path-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        for megabytes in [1, 10] {
            let storage = try Storage(
                path: directory.appendingPathComponent("\(megabytes).sqlite").path,
                installStarterContent: false
            )
            let payload = Data(repeating: 42, count: megabytes * 1_024 * 1_024)
            let id = try XCTUnwrap(storage.insert(ClipItem(
                kind: .image, title: "Synthetic image", data: payload, createdAt: Date()
            )))
            try record("ocr-\(megabytes)MB", iterations: 12) { index in
                try storage.setOCRText("Synthetic OCR Привет \(index)", forClipID: id)
            }
            try record("pin-\(megabytes)MB", iterations: 12) { _ in
                try storage.setPinned(id: id, pinned: true)
            }
            let expectedOCR = "Synthetic OCR Привет 11"
            try record("ocr-full-fetch-\(megabytes)MB", iterations: 20) { _ in
                let item = try storage.fetchClip(id: id)
                XCTAssertEqual(item?.ocrText, expectedOCR)
                XCTAssertEqual(item?.data?.count, payload.count)
            }
            try record("ocr-projected-fetch-\(megabytes)MB", iterations: 20) { _ in
                let item = try storage.fetchOCRTextItem(id: id)
                XCTAssertEqual(item?.text, expectedOCR)
                XCTAssertNil(item?.data)
            }
            XCTAssertEqual(try storage.fetchClip(id: id)?.data, payload)
        }

        let text = String(repeating: "Синтетический текст é ", count: 65_536)
        record("empty-rules-\(text.utf8.count)B", iterations: 20) { _ in
            XCTAssertFalse(SensitiveContentPolicy.matches(text, normalizedRules: []))
        }
    }

    private func record(
        _ label: String,
        iterations: Int,
        operation: (Int) throws -> Void
    ) rethrows {
        var milliseconds: [Double] = []
        for index in 0..<iterations {
            let start = DispatchTime.now().uptimeNanoseconds
            try operation(index)
            milliseconds.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
        }
        milliseconds.sort()
        let median = milliseconds[milliseconds.count / 2]
        let p95 = milliseconds[min(milliseconds.count - 1, Int(Double(milliseconds.count) * 0.95))]
        print("NECLIP_BENCH \(label) n=\(iterations) median_ms=\(median) p95_ms=\(p95)")
    }
}
