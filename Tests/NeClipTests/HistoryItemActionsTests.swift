import Foundation
import Testing
@testable import NeClip

@Suite(.serialized)
struct HistoryItemActionsTests {
    @Test func resolvesOnlyExplicitSafeOpenTargets() {
        let web = textItem("https://affpapa.org/neclip")
        #expect(HistoryItemActionResolver.openTarget(for: web)?.scheme == "https")
        #expect(HistoryItemActionResolver.openTarget(for: textItem("file:///tmp/private")) == nil)
        #expect(HistoryItemActionResolver.openTarget(for: textItem("https://example.com path")) == nil)

        let file = ClipItem(
            kind: .file,
            title: "report.txt",
            text: "/tmp/report.txt\n/tmp/other.txt",
            createdAt: Date()
        )
        #expect(
            HistoryItemActionResolver.openTarget(for: file, fileExists: { $0 == "/tmp/report.txt" })?.path
                == "/tmp/report.txt"
        )
        #expect(HistoryItemActionResolver.openTarget(for: file, fileExists: { _ in false }) == nil)
    }

    @Test func editsTextAndRenamesTransactionally() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let original = ClipItem(
            kind: .text,
            title: "Old",
            text: "old body",
            rtf: Data([1, 2, 3]),
            createdAt: Date()
        )
        let insertedID = try storage.insert(original)
        let id = try #require(insertedID)

        let updated = try storage.updateClip(id: id, title: "New title", text: "new body")
        #expect(updated.title == "New title")
        #expect(updated.text == "new body")
        #expect(updated.rtf == nil)
        #expect(updated.contentHash != nil)
        #expect(updated.contentBytes == Int64("new body".utf8.count))
    }

    @Test func rejectsEmptyEditedTextWithoutChangingStoredItem() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let insertedID = try storage.insert(textItem("keep me"))
        let id = try #require(insertedID)

        #expect(throws: ClipStorageError.emptyText) {
            try storage.updateClip(id: id, title: "ignored", text: "   ")
        }
        let fetched = try storage.fetchClip(id: id)
        let stored = try #require(fetched)
        #expect(stored.title == "keep me")
        #expect(stored.text == "keep me")
    }

    private func textItem(_ value: String) -> ClipItem {
        ClipItem(kind: .text, title: value, text: value, createdAt: Date())
    }
}
