import Foundation
import XCTest
@testable import NeClip

final class FocusStackTests: XCTestCase {
    func testCurrentAppClipsLeadAndUsedSnippetsFillTheSmallWorkingSet() {
        let now = Date()
        let appClip = ClipSummary(
            id: 1,
            kind: .text,
            title: "Из этого приложения",
            text: "A",
            appBundleID: "com.example.Editor",
            createdAt: now,
            isPinned: false
        )
        let otherClip = ClipSummary(
            id: 2,
            kind: .text,
            title: "Другое приложение",
            text: "B",
            appBundleID: "com.example.Other",
            createdAt: now.addingTimeInterval(-1),
            isPinned: false
        )
        let used = SnippetSummary(snippet: Snippet(
            id: 3,
            folderID: nil,
            title: "Ответ",
            content: "Готовый ответ",
            useCount: 2,
            lastUsedAt: now
        ))
        let unused = SnippetSummary(snippet: Snippet(
            id: 4,
            folderID: nil,
            title: "Новый",
            content: "Не показывать",
            useCount: 0
        ))

        let result = FocusStack.items(
            clips: [otherClip, appClip],
            snippets: [unused, used],
            currentBundleID: "COM.EXAMPLE.EDITOR"
        )

        XCTAssertEqual(result, [.clip(appClip), .snippet(used)])
    }

    func testOneContextItemDoesNotCreateASecondMenuSection() {
        let clip = ClipSummary(
            id: 1,
            kind: .text,
            title: "Один",
            text: "A",
            appBundleID: "com.example.Editor",
            createdAt: Date(),
            isPinned: false
        )
        XCTAssertTrue(FocusStack.items(clips: [clip], snippets: [], currentBundleID: "com.example.Editor").isEmpty)
    }

    func testNoCurrentAppDoesNotGuessAWorkingSet() {
        XCTAssertTrue(FocusStack.items(clips: [], snippets: [], currentBundleID: nil).isEmpty)
    }
}
