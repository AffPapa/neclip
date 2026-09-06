import AppKit
import XCTest
@testable import NeClip

final class MenuWorkRegressionTests: XCTestCase {
    @MainActor
    func testPaginationKeepsExactRangesAndAbsoluteIndices() throws {
        for count in [0, 10, 11, 25, 100] {
            let menu = NSMenu()
            MenuPagination.appendPages(count: count, to: menu,
                makeMenu: { NSMenu(title: $0) },
                makeItem: { index in
                    let item = NSMenuItem(title: "Item \(index)", action: nil, keyEquivalent: "")
                    item.representedObject = index
                    return item
                })
            let expected = stride(from: 10, to: count, by: 10).map {
                "\($0 + 1)–\(min($0 + 10, count))"
            }
            XCTAssertEqual(menu.items.map(\.title), expected)
            let indices = try menu.items.flatMap { parent in
                try XCTUnwrap(parent.submenu).items.compactMap { $0.representedObject as? Int }
            }
            XCTAssertEqual(indices, count > 10 ? Array(10..<count) : [])
            XCTAssertTrue(menu.items.allSatisfy { ($0.submenu?.items.count ?? 0) <= 10 })
        }
    }

    func testSupersededQueuedSearchDoesNotRunAndLatestRuns() {
        let queue = DispatchQueue(label: "test.menu-search")
        queue.suspend()
        let obsoleteRan = expectation(description: "obsolete SQL must not run")
        obsoleteRan.isInverted = true
        let latestRan = expectation(description: "latest SQL runs")
        let obsolete = MenuSearchWork.enqueue(on: queue) { obsoleteRan.fulfill() }
        obsolete.cancel()
        _ = MenuSearchWork.enqueue(on: queue) { latestRan.fulfill() }
        queue.resume()
        wait(for: [latestRan], timeout: 2)
        wait(for: [obsoleteRan], timeout: 0.02)
    }
}
