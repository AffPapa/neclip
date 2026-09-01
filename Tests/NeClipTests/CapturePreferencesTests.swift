import XCTest
@testable import NeClip

final class CapturePreferencesTests: XCTestCase {
    private var previousRetention = 0
    private var previousRules: [String] = []
    private var previousHistoryLimit = 100
    private var previousMaximumTextCaptureKilobytes = 2_048
    private var previousClearHistoryOnQuit = false

    override func setUp() {
        super.setUp()
        previousRetention = Settings.retentionDays
        previousRules = Settings.sensitiveContentRules
        previousHistoryLimit = Settings.historyLimit
        previousMaximumTextCaptureKilobytes = Settings.maximumTextCaptureKilobytes
        previousClearHistoryOnQuit = Settings.clearHistoryOnQuit
        Settings.retentionDays = 0
        Settings.sensitiveContentRules = []
    }

    override func tearDown() {
        Settings.retentionDays = previousRetention
        Settings.sensitiveContentRules = previousRules
        Settings.historyLimit = previousHistoryLimit
        Settings.maximumTextCaptureKilobytes = previousMaximumTextCaptureKilobytes
        Settings.clearHistoryOnQuit = previousClearHistoryOnQuit
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

    func testMaximumTextCaptureIsClampedAndCountsRichPayload() {
        Settings.maximumTextCaptureKilobytes = 1
        XCTAssertEqual(Settings.maximumTextCaptureKilobytes, 64)
        Settings.maximumTextCaptureKilobytes = 99_999
        XCTAssertEqual(Settings.maximumTextCaptureKilobytes, 2_048)

        XCTAssertTrue(ClipboardCapturePolicy.acceptsTextPayload(
            textBytes: 40 * 1_024,
            rtfBytes: 20 * 1_024,
            userLimit: 64 * 1_024
        ))
        XCTAssertFalse(ClipboardCapturePolicy.acceptsTextPayload(
            textBytes: 40 * 1_024,
            rtfBytes: 25 * 1_024,
            userLimit: 64 * 1_024
        ))
        XCTAssertEqual(
            ClipboardCapturePolicy.effectiveTextPayloadLimit(userLimit: Int.max),
            ClipboardCapturePolicy.maxTextBytes
        )
    }

    func testClearOnQuitPreferenceDefaultsToExplicitLocalToggle() {
        Settings.clearHistoryOnQuit = true
        XCTAssertTrue(Settings.clearHistoryOnQuit)
        Settings.clearHistoryOnQuit = false
        XCTAssertFalse(Settings.clearHistoryOnQuit)
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
