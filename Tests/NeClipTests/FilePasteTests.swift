import AppKit
import XCTest
@testable import NeClip

final class FilePasteTests: XCTestCase {
    @MainActor
    func testPlainFilePasteWritesReadablePathsWithoutFileRepresentation() async throws {
        let paths = ["/tmp/Отчёт 你好.txt", "/tmp/line\nname.txt"]
        let encoded = try XCTUnwrap(FileClipboardCodec.encode(paths.map { URL(fileURLWithPath: $0) }))
        for (stored, expected) in [(encoded, paths.joined(separator: "\n")),
                                   ("/tmp/legacy one.txt\n/tmp/legacy two.txt", "/tmp/legacy one.txt\n/tmp/legacy two.txt")] {
            let board = NSPasteboard(name: .init("neclip-file-paste-\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            let done = expectation(description: "plain file copied")
            PasteService.paste(ClipItem(kind: .file, title: "Fixture", text: stored, createdAt: Date()),
                               plainText: true, targetPID: nil, copyOnly: true, pasteboard: board) {
                XCTAssertEqual($0, .copiedOnly); done.fulfill()
            }
            await fulfillment(of: [done], timeout: 2)
            XCTAssertEqual(board.string(forType: .string), expected)
            XCTAssertFalse(board.types?.contains(.fileURL) ?? false)
        }
    }

    @MainActor
    func testOriginalFilePastePreservesFileObjectsAndEmptyFileRestoresClipboard() async throws {
        let board = NSPasteboard(name: .init("neclip-file-original-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        let paths = [URL(fileURLWithPath: "/tmp/first.txt"), URL(fileURLWithPath: "/tmp/second.txt")]
        let done = expectation(description: "original file copied")
        PasteService.paste(ClipItem(kind: .file, title: "Fixture", text: FileClipboardCodec.encode(paths), createdAt: Date()),
                           plainText: false, targetPID: nil, copyOnly: true, pasteboard: board) {
            XCTAssertEqual($0, .copiedOnly); done.fulfill()
        }
        await fulfillment(of: [done], timeout: 2)
        XCTAssertEqual(board.readObjects(forClasses: [NSURL.self]) as? [URL], paths)
        board.clearContents()
        XCTAssertTrue(board.setString("keep", forType: .string))
        var result: PasteResult?
        PasteService.paste(ClipItem(kind: .file, title: "Empty", text: "[]", createdAt: Date()),
                           plainText: true, targetPID: nil, copyOnly: true, pasteboard: board) { result = $0 }
        XCTAssertEqual(result, .failed(.clipboardWrite))
        XCTAssertEqual(board.string(forType: .string), "keep")
    }
}
