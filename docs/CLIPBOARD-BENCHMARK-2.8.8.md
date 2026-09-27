# Direct clipboard preparation microbenchmark

Stable Xcode Swift 6.4.0.34.1, optimized `-O`, arm64, macOS 27.0 (26A5416b). 8 MiB ASCII on a unique named pasteboard; five warmups and 40 paired samples. The eager path matches the removed unconditional `string(forType:)`; the lazy path calls the production helper with a literal template. The user's general clipboard is never changed.

| Path | p50 ms | p95 ms | Text reads per preparation |
| --- | ---: | ---: | ---: |
| Eager | 0.352375 | 0.420542 | 1 |
| Lazy literal | 0.000125 | 0.000375 | 0 |

These measurements exclude final paste, provider delays, and the separate rollback snapshot. They do not establish end-to-end UI speedup. The temporary constant below is the unchanged `ClipboardCapturePolicy.maxTextBytes` required to compile the unused renderer default argument; no policy behavior is benchmarked.

Save the following harness as `/tmp/neclip-clipboard-benchmark.swift`, then from the source checkout run:

```sh
printf '%s\n' 'enum ClipboardCapturePolicy { static let maxTextBytes = 2 * 1024 * 1024 }' > /tmp/neclip-benchmark-policy.swift
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O Sources/NeClip/SnippetTokenCatalog.swift Sources/NeClip/SnippetRenderer.swift Sources/NeClip/SnippetClipboardRead.swift /tmp/neclip-benchmark-policy.swift /tmp/neclip-clipboard-benchmark.swift -o /tmp/neclip-clipboard-benchmark
/tmp/neclip-clipboard-benchmark
```

```swift
import AppKit
import Foundation

@main
struct ClipboardPreparationBenchmark {
    @MainActor
    static func main() throws {
        let board = NSPasteboard(name: .init("neclip.audit.benchmark.\(UUID())"))
        defer { board.releaseGlobally() }
        board.clearContents()
        precondition(board.setString(String(repeating: "x", count: 8 * 1024 * 1024), forType: .string))
        let generation = board.changeCount
        let template = "Literal synthetic snippet"
        var checksum = 0
        var before: [Double] = [], after: [Double] = []
        for iteration in 0..<45 {
            let old = autoreleasepool { () -> Double in
                let start = DispatchTime.now().uptimeNanoseconds
                let value = board.string(forType: .string)
                if value?.isEmpty == false { checksum += 1 }
                return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            }
            let new = try autoreleasepool { () throws -> Double in
                let start = DispatchTime.now().uptimeNanoseconds
                let value = try SnippetClipboardRead.readIfNeeded(template: template, expectedGeneration: generation,
                    readGeneration: { board.changeCount }, readText: { board.string(forType: .string) })
                precondition(value == nil)
                return Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            }
            if iteration >= 5 { before.append(old); after.append(new) }
        }
        func stats(_ values: [Double]) -> [String: Double] {
            let s = values.sorted()
            return ["p50_ms": s[s.count / 2], "p95_ms": s[Int(Double(s.count) * 0.95) - 1]]
        }
        let output: [String: Any] = ["scope": "direct literal-template clipboard preparation only; excludes final paste/rollback snapshot",
            "fixtureBytes": 8 * 1024 * 1024, "samples": 40, "warmup": 5,
            "before": stats(before), "after": stats(after), "beforeReads": checksum, "afterReads": 0]
        let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
```
