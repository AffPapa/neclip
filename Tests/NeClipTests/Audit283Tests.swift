import AppKit
import GRDB
import ImageIO
import XCTest
@testable import NeClip

final class Audit283Tests: XCTestCase {
    @MainActor
    func testDeferredPasteRejectsChangedClipboardAndOnlyNewestRequestPosts() async throws {
        let board = NSPasteboard(name: .init("neclip-audit-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.clearContents()
        board.setString("first", forType: .string)
        let rejected = expectation(description: "stale paste rejected")
        let newest = expectation(description: "current paste posted")
        var posted = 0
        PasteService.completePaste(copyOnly: false, targetPID: 42, expectedGeneration: board.changeCount,
                                   pasteboard: board, currentPID: { 42 }, trusted: { true },
                                   postPaste: { _ in XCTFail("Stale paste posted"); return true }) {
            XCTAssertEqual($0, .failed(.clipboardChanged)); rejected.fulfill()
        }
        board.clearContents()
        board.setString("second", forType: .string)
        PasteService.completePaste(copyOnly: false, targetPID: 42, expectedGeneration: board.changeCount,
                                   pasteboard: board, currentPID: { 42 }, trusted: { true },
                                   postPaste: { _ in posted += 1; return true }) {
            XCTAssertEqual($0, .pasted); newest.fulfill()
        }
        await fulfillment(of: [rejected, newest], timeout: 2)
        XCTAssertEqual(posted, 1)
        XCTAssertEqual(board.string(forType: .string), "second")
    }

}
