import AppKit
import XCTest
@testable import NeClip

final class MenuSearchUXTests: XCTestCase {
    func testPageDistinguishesExactLimitAndOverflowWithoutChangingOrder() {
        XCTAssertTrue(MenuSearchPage<Int>([]).entries.isEmpty)
        XCTAssertFalse(MenuSearchPage(Array(0..<20)).hasMore)
        let page = MenuSearchPage(Array(0..<21))
        XCTAssertTrue(page.hasMore)
        XCTAssertEqual(page.entries, Array(0..<20))
        let mixed = MenuSearchPage(["exact snippet"] + (0..<20).map { "clip \($0)" })
        XCTAssertTrue(mixed.hasMore)
        XCTAssertEqual(mixed.entries.first, "exact snippet")
        XCTAssertEqual(mixed.entries.count, 20)
    }

    func testEditingQueryDoesNotInvokeDestructiveHistoryShortcuts() {
        XCTAssertTrue(MenuSearchKeyPolicy.allowsHistoryMutation(searchText: ""))
        XCTAssertFalse(MenuSearchKeyPolicy.allowsHistoryMutation(searchText: "query"))
        XCTAssertFalse(MenuSearchKeyPolicy.allowsHistoryMutation(searchText: " "))
        XCTAssertTrue(MenuSearchKeyPolicy.shouldNavigateToMenu(keyCode: 125, modifiers: []))
        XCTAssertTrue(MenuSearchKeyPolicy.shouldNavigateToMenu(keyCode: 126, modifiers: []))
        XCTAssertFalse(MenuSearchKeyPolicy.shouldNavigateToMenu(keyCode: 125, modifiers: .option))
        XCTAssertFalse(MenuSearchKeyPolicy.shouldNavigateToMenu(keyCode: 126, modifiers: .command))
    }
}
