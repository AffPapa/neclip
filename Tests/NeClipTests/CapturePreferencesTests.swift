import XCTest
@testable import NeClip

final class CapturePreferencesTests: XCTestCase {
    private var previousRetention = 0
    private var previousRules: [String] = []
    private var previousHistoryLimit = 100

    override func setUp() {
        super.setUp()
        previousRetention = Settings.retentionDays
        previousRules = Settings.sensitiveContentRules
        previousHistoryLimit = Settings.historyLimit
        Settings.retentionDays = 0
        Settings.sensitiveContentRules = []
    }

    override func tearDown() {
        Settings.retentionDays = previousRetention
        Settings.sensitiveContentRules = previousRules
        Settings.historyLimit = previousHistoryLimit
        super.tearDown()
    }

    func testSensitiveRulesAreBoundedDeduplicatedAndCaseInsensitive() {
        let rules = SensitiveContentPolicy.normalizedRules([
            "  client-secret  ", "CLIENT-SECRET", "кодовое слово"
        ])
        XCTAssertEqual(rules, ["client-secret", "кодовое слово"])
        XCTAssertTrue(SensitiveContentPolicy.matches("CLIENT-SECRET=abc", rules: rules))
        XCTAssertTrue(SensitiveContentPolicy.matches("Это Кодовое Слово", rules: rules))
        XCTAssertFalse(SensitiveContentPolicy.matches("обычная заметка", rules: rules))
    }

    func testHistoryLimitIsClampedAtTheSettingsBoundary() {
        Settings.historyLimit = 1
        XCTAssertEqual(Settings.historyLimit, 10)
        Settings.historyLimit = 10_000
        XCTAssertEqual(Settings.historyLimit, 1_000)
    }

    func testAgeRetentionDeletesOnlyOldUnpinnedClips() throws {
        Settings.retentionDays = 0
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let oldPinned = try XCTUnwrap(storage.insert(ClipItem(
            kind: .text,
            title: "old pinned",
            text: "old pinned unique",
            createdAt: Date().addingTimeInterval(-30 * 86_400)
        )))
        try storage.setPinned(id: oldPinned, pinned: true)
        let old = try storage.insert(ClipItem(
            kind: .text,
            title: "old",
            text: "old unpinned unique",
            createdAt: Date().addingTimeInterval(-30 * 86_400)
        ))
        let recent = try storage.insert(ClipItem(
            kind: .text,
            title: "recent",
            text: "recent unique",
            createdAt: Date()
        ))
        Settings.retentionDays = 7
        try storage.trimToLimits()

        XCTAssertNil(try storage.fetchClip(id: XCTUnwrap(old)))
        XCTAssertNotNil(try storage.fetchClip(id: XCTUnwrap(recent)))
        XCTAssertNotNil(try storage.fetchClip(id: oldPinned))
    }
}
