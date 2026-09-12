import Foundation
import XCTest
@testable import NeClip

/// Opt-in synthetic benchmark. Setup and full-payload verification are excluded
/// from timings; this never opens the user's database or pasteboard.
final class HotPathBenchmarks: XCTestCase {
    func testSyntheticDigestHexadecimalLatency() throws {
        guard ProcessInfo.processInfo.environment["NECLIP_RUN_HOT_PATH_BENCHMARKS"] == "1" else {
            throw XCTSkip("Opt-in synthetic digest hexadecimal benchmark")
        }
        let fixtures = (0..<256).map { first in
            [UInt8(first)] + Array(UInt8(1)...UInt8(31))
        }
        var formattedBytes = 0
        var encodedBytes = 0
        record("hex-formatter-256-digests", iterations: 50) { _ in
            for bytes in fixtures {
                formattedBytes += bytes.map { String(format: "%02x", $0) }.joined().utf8.count
            }
        }
        record("hex-nibbles-256-digests", iterations: 50) { _ in
            for bytes in fixtures {
                encodedBytes += ContentDigest.hexadecimal(bytes).utf8.count
            }
        }
        XCTAssertEqual(formattedBytes, 50 * 256 * 64)
        XCTAssertEqual(encodedBytes, formattedBytes)
        // These timings isolate digest encoding, not SHA-256, capture, or menu
        // latency. No speed threshold: shared hosts and sanitizers affect timing.
    }

    func testSyntheticMenuRefreshReadLatency() throws {
        guard ProcessInfo.processInfo.environment["NECLIP_RUN_HOT_PATH_BENCHMARKS"] == "1" else {
            throw XCTSkip("Opt-in synthetic menu read benchmark")
        }
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let folderID = try XCTUnwrap(storage.addFolder(title: "Synthetic")?.id)
        for index in 0..<200 {
            _ = try storage.addSnippet(folderID: folderID, title: "Snippet \(index)",
                                      content: String(repeating: "Synthetic body ", count: 150))
            _ = try storage.insert(ClipItem(kind: .text, title: "Clip \(index)",
                                           text: "Unique synthetic \(index)", createdAt: Date()))
        }
        let readClips = {
            _ = try storage.summaries(limit: 101, pinnedOnly: true)
            _ = try storage.summaries(limit: 101, pinnedOnly: false, unpinnedOnly: true)
        }
        // Same fixture and warmed cache. Only DB/projection work is timed,
        // not native menu rendering, writes, capture, or application startup.
        try readClips()
        _ = try storage.menuSnippetSnapshot()
        try record("menu-full", iterations: 100) { _ in
            try readClips()
            _ = try storage.menuSnippetSnapshot()
        }
        try record("menu-clips-only", iterations: 100) { _ in try readClips() }
        try record("menu-snippets-only", iterations: 100) { _ in
            _ = try storage.menuSnippetSnapshot()
        }
    }

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
            try record("pin-\(megabytes)MB", iterations: 12) { _ in
                try storage.setPinned(id: id, pinned: true)
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
