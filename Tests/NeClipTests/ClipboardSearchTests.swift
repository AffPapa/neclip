import Foundation
import Testing
@testable import NeClip

@Suite(.serialized)
struct ClipboardSearchTests {
    @Test func parsesStructuredFiltersWithoutLeakingThemIntoTerms() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let query = ClipboardSearchQuery.parse(
            "invoice type:link app:Safari when:week is:pinned",
            now: now,
            calendar: calendar
        )

        #expect(query.terms == "invoice")
        #expect(query.kind == .text)
        #expect(query.smartCategory == .link)
        #expect(query.appFragment == "safari")
        #expect(query.pinFilter == .pinned)
        #expect(query.since == calendar.date(byAdding: .day, value: -7, to: now))
    }

    @Test func acceptsExactBundleIdentifierForAnApplicationWithASpacedName() {
        let query = ClipboardSearchQuery.parse("app:com.google.Chrome")
        #expect(query.terms.isEmpty)
        #expect(query.appFragment == "com.google.chrome")
    }

    @Test func leavesUnknownFiltersSearchable() {
        let query = ClipboardSearchQuery.parse("owner:alex report")
        #expect(query.terms == "owner:alex report")
        #expect(!query.usesStructuredFilters)
    }

    @Test func classifiesUsefulTextTypesLocally() {
        #expect(SmartClipClassifier.category(for: summary("https://affpapa.org/neclip")) == .link)
        #expect(SmartClipClassifier.category(for: summary("hello@example.com")) == .email)
        #expect(SmartClipClassifier.category(for: summary("#ff5500")) == .color)
        #expect(SmartClipClassifier.category(for: summary("func hello() { return 1 }")) == .code)
        #expect(SmartClipClassifier.category(for: summary("ordinary sentence")) == nil)
    }

    @Test func fuzzyFallbackRanksTyposButRejectsUnrelatedText() {
        let entries = [summary("payment invoice"), summary("release notes"), summary("meeting plan")]
        let ranked = ClipboardFuzzySearch.ranked(entries, query: "invoce", limit: 10)
        #expect(ranked.map(\.title) == ["payment invoice"])
        #expect(ClipboardFuzzySearch.ranked(entries, query: "elephant", limit: 10).isEmpty)
    }

    @Test func storageCombinesSQLAndSemanticFilters() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let now = Date()
        _ = try storage.insert(item("https://example.com", app: "com.apple.Safari", date: now, pinned: true))
        _ = try storage.insert(item("hello@example.com", app: "com.apple.Mail", date: now, pinned: false))
        _ = try storage.insert(item("weekly report", app: "com.apple.Safari", date: now, pinned: false))
        _ = try storage.insert(item("browser value", app: "com.google.Chrome", date: now, pinned: false))

        let links = try storage.searchSummaries(
            query: .parse("type:link app:safari is:pinned"),
            limit: 20
        )
        #expect(links.map(\.title) == ["https://example.com"])

        let typo = try storage.searchSummaries(query: .parse("weeekly"), limit: 20)
        #expect(typo.map(\.title) == ["weekly report"])

        let twoWordApplication = try storage.searchSummaries(
            query: .parse("app:com.google.Chrome"),
            limit: 20
        )
        #expect(twoWordApplication.map(\.title) == ["browser value"])
    }

    @Test func semanticFiltersPagePastTwoHundredRecentUnrelatedItems() throws {
        let previousLimit = Settings.historyLimit
        Settings.historyLimit = 1_000
        defer { Settings.historyLimit = previousLimit }

        let storage = try Storage(inMemory: true, installStarterContent: false)
        let oldLink = "https://example.com/older-link"
        _ = try storage.insert(item(oldLink, app: "com.apple.Safari", date: .distantPast, pinned: false))
        for index in 0..<250 {
            _ = try storage.insert(item(
                "ordinary clipboard value \(index)",
                app: "com.apple.TextEdit",
                date: Date(timeIntervalSince1970: TimeInterval(index + 1)),
                pinned: false
            ))
        }

        let links = try storage.searchSummaries(query: .parse("type:link"), limit: 20)
        #expect(links.map(\.title) == [oldLink])
    }

    private func summary(_ value: String) -> ClipSummary {
        ClipSummary(
            id: Int64(abs(value.hashValue)),
            kind: .text,
            title: value,
            text: value,
            appBundleID: nil,
            createdAt: Date(),
            isPinned: false
        )
    }

    private func item(
        _ value: String,
        app: String,
        date: Date,
        pinned: Bool
    ) -> ClipItem {
        ClipItem(
            kind: .text,
            title: value,
            text: value,
            appBundleID: app,
            createdAt: date,
            isPinned: pinned,
            pinnedAt: pinned ? date : nil
        )
    }
}
