import XCTest
@testable import NeClip

final class StorageStatisticsTests: XCTestCase {
    func testCountsIncludeAllSnippetsAndFollowHistoryClearAndRestore() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        XCTAssertEqual(try storage.statistics(), .init(history: 0, snippets: 0))
        for index in 0..<205 {
            _ = try storage.addSnippet(folderID: nil, title: "Count \(index)", content: "Synthetic \(index)")
        }
        _ = try storage.insert(ClipItem(kind: .text, title: "History", text: "History", createdAt: Date()))
        XCTAssertEqual(try storage.statistics(), .init(history: 1, snippets: 205))
        let exported = try storage.exportSnippetData()
        try storage.clearHistory(includePinned: true)
        XCTAssertEqual(try storage.statistics(), .init(history: 0, snippets: 205))
        try storage.deleteAllUserData()
        XCTAssertEqual(try storage.statistics(), .init(history: 0, snippets: 0))
        _ = try storage.importSnippetData(exported)
        XCTAssertEqual(try storage.statistics(), .init(history: 0, snippets: 205))
    }
}
