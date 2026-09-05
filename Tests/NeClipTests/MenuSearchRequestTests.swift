import AppKit
import XCTest
@testable import NeClip

final class MenuSearchRequestTests: XCTestCase {
    func testSnippetSearchDoesNotInterpretTemplateTextAsHistoryFilters() {
        for text in ["app:example", "type:text", "when:today", "is:pinned", ";hello"] {
            let request = MenuSearchRequest("  \(text)  ", snippetsOnly: true)
            XCTAssertNil(request.history)
            XCTAssertEqual(request.snippetTerms, text)
        }
    }

    func testHistoryFiltersDoNotLeakIntoSnippetSearch() {
        let request = MenuSearchRequest("type:image receipt", snippetsOnly: false)
        XCTAssertEqual(request.history?.kind, .image)
        XCTAssertEqual(request.history?.terms, "receipt")
        XCTAssertNil(request.snippetTerms)
        XCTAssertEqual(MenuSearchRequest(";hello", snippetsOnly: false).snippetTerms, ";hello")
    }

    func testChoosingFilterReplacesOnlyItsDimensionIncludingAliases() {
        XCTAssertEqual(MenuSearchRequest.replacingFilter(
            in: "invoice тип:текст app:com.apple.Notes when:week", with: "type:image"
        ), "invoice app:com.apple.Notes when:week type:image")
        XCTAssertEqual(MenuSearchRequest.replacingFilter(
            in: "type:custom app:old source:older query", with: "app:new"
        ), "type:custom query app:new")
        XCTAssertEqual(MenuSearchRequest.replacingFilter(
            in: "is:history when:week", with: "is:pinned"
        ), "when:week is:pinned")
        XCTAssertEqual(MenuSearchRequest.replacingFilter(in: "type:image", with: "type:image"), "type:image")
    }

    @MainActor
    func testStandardFooterHasEnabledExplicitTargetsAndConsistentShortcuts() {
        let target = NSObject()
        let menu = NSMenu()
        menu.autoenablesItems = false
        StatusBarController.appendStandardFooter(to: menu, target: target)
        XCTAssertEqual(menu.items.map(\.keyEquivalent), [",", "", "q"])
        XCTAssertTrue(menu.items[1].isSeparatorItem)
        for item in [menu.items[0], menu.items[2]] {
            XCTAssertTrue(item.isEnabled)
            XCTAssertTrue(item.target === target)
            XCTAssertNotNil(item.action)
            XCTAssertEqual(item.keyEquivalentModifierMask, [.command])
        }
    }

    func testFolderOrderIgnoresTitleAndRecentUseAndBreaksTiesByID() {
        var a = Snippet(folderID: nil, title: "Zulu", content: "a", sortIndex: 0)
        a.id = 1
        var b = Snippet(folderID: nil, title: "Alpha", content: "b", sortIndex: 0)
        b.id = 2
        var c = Snippet(folderID: nil, title: "First", content: "c", sortIndex: 1)
        c.id = 3
        let sorted = [c, b, a].map { SnippetSummary(snippet: $0) }.sorted(by: SnippetMenuOrder.lessThan)
        XCTAssertEqual(sorted.compactMap(\.id), [1, 2, 3])
    }
}
