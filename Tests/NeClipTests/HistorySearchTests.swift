import AppKit
import Carbon
import Foundation
import XCTest
@testable import NeClip

final class HistorySearchTests: XCTestCase {
    func testFileSearchMatchesDisplayedPathNotJSONEscaping() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let path = "/tmp/synthetic folder/name\nline.txt"
        let encoded = try XCTUnwrap(FileClipboardCodec.encode([URL(fileURLWithPath: path)]))
        try storage.insert(ClipItem(kind: .file, title: "Fixture file", text: encoded, createdAt: Date()))
        for query in ["/tmp/synthetic folder/", "name\nline", path] {
            XCTAssertEqual(try storage.searchClipSummaries(query: query, kind: .file).count, 1, query)
        }
    }

    @MainActor
    private func settle(_ queue: DispatchQueue) async {
        await withCheckedContinuation { continuation in
            queue.async { DispatchQueue.main.async { continuation.resume() } }
        }
    }

    @MainActor
    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    @MainActor
    func testChangingQueryImmediatelyBlocksEveryActionOnOldSelection() async throws {
        _ = NSApplication.shared
        let queue = DispatchQueue(label: "test.search.actions")
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.insert(ClipItem(kind: .text, title: "A", text: "old value", createdAt: Date()))
        await settle(queue)
        let controller = HistorySearchPanelController(storage: storage, dataQueue: queue)
        var actions: [Int64] = []
        controller.prepare(targetPID: nil, paste: { id, _, _, _ in actions.append(id) },
                           save: { actions.append($0) }, open: { actions.append($0) })
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        let views = descendants(try XCTUnwrap(window.contentView))
        let field = try XCTUnwrap(views.compactMap { $0 as? NSSearchField }.first)
        let table = try XCTUnwrap(views.compactMap { $0 as? NSTableView }.first)
        await settle(queue)
        XCTAssertEqual(table.numberOfRows, 1)
        XCTAssertEqual(table.selectedRow, 0)

        field.stringValue = "B"
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(field.action), to: field.target, from: field))
        XCTAssertEqual(table.numberOfRows, 0, "The 120ms debounce must not expose A to Return or a mouse action")
        for selector in ["pasteOriginal", "pastePlain", "copyOnly", "saveAsSnippet", "openTarget"] {
            XCTAssertTrue(NSApp.sendAction(NSSelectorFromString(selector), to: controller, from: nil))
        }
        XCTAssertTrue(actions.isEmpty)
        let actionTitles = ["Вставить", "Обычный текст", "Только скопировать", "Сохранить в сниппеты", "Открыть"]
        let actionButtons = views.compactMap { $0 as? NSButton }.filter { actionTitles.contains($0.title) }
        XCTAssertEqual(actionButtons.count, 5)
        for button in actionButtons {
            XCTAssertFalse(button.isEnabled)
        }
    }

    @MainActor
    func testErasureClearsVisibleTextAndRejectsAnAlreadyReadReply() async throws {
        _ = NSApplication.shared
        let queue = DispatchQueue(label: "test.search.erasure")
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.insert(ClipItem(kind: .text, title: "Private", text: "private body",
                                       appBundleID: "org.test.private", createdAt: Date()))
        await settle(queue)
        let controller = HistorySearchPanelController(storage: storage, dataQueue: queue)
        controller.prepare(targetPID: nil, paste: { _, _, _, _ in XCTFail("No stale paste") }, save: { _ in }, open: { _ in })
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        let table = try XCTUnwrap(descendants(try XCTUnwrap(window.contentView)).compactMap { $0 as? NSTableView }.first)
        await settle(queue)
        XCTAssertEqual(table.numberOfRows, 1)
        XCTAssertTrue(NSApp.sendAction(NSSelectorFromString("retrySearch"), to: controller, from: nil))
        // SQL has read private text, but its completion cannot run on the main
        // actor until this synchronous section yields.
        queue.sync {}
        try storage.deleteAllUserData()
        NotificationCenter.default.post(name: .neClipStorageDidChange, object: storage,
                                         userInfo: [StorageChangeDomain.notificationKey: "all"])
        XCTAssertEqual(table.numberOfRows, 0)
        await settle(queue)
        await settle(queue)
        XCTAssertEqual(table.numberOfRows, 0)
        XCTAssertTrue(try storage.searchClipSummaries(query: "").isEmpty)
        let labels = descendants(try XCTUnwrap(window.contentView)).compactMap { ($0 as? NSTextField)?.stringValue }
        XCTAssertFalse(labels.contains { $0.contains("private body") || $0 == "Private" })
    }

    @MainActor
    func testRemovedApplicationFilterFallsBackToAllApplicationsAndRefreshesResults() async throws {
        _ = NSApplication.shared
        let queue = DispatchQueue(label: "test.search.removed-app")
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let removedID = try XCTUnwrap(try storage.insert(ClipItem(kind: .text, title: "Removed", text: "old",
            appBundleID: "org.test.removed", createdAt: Date())))
        _ = try storage.insert(ClipItem(kind: .text, title: "Remaining", text: "current",
            appBundleID: "org.test.remaining", createdAt: Date()))
        let controller = HistorySearchPanelController(storage: storage, dataQueue: queue)
        controller.prepare(targetPID: nil, paste: { _, _, _, _ in }, save: { _ in }, open: { _ in })
        let window = try XCTUnwrap(controller.window)
        defer { window.close() }
        let views = descendants(try XCTUnwrap(window.contentView))
        let table = try XCTUnwrap(views.compactMap { $0 as? NSTableView }.first)
        await settle(queue)
        await settle(queue)
        let appPopup = try XCTUnwrap(views.compactMap { $0 as? NSPopUpButton }.first {
            $0.itemArray.contains { ($0.representedObject as? String) == "" }
        })
        let removedIndex = try XCTUnwrap(appPopup.itemArray.firstIndex {
            ($0.representedObject as? String) == "org.test.removed"
        })
        appPopup.selectItem(at: removedIndex)
        XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(appPopup.action), to: appPopup.target, from: appPopup))
        await settle(queue)
        await settle(queue)
        XCTAssertEqual(table.numberOfRows, 1)

        let changed = expectation(forNotification: .neClipStorageDidChange, object: storage)
        _ = try storage.removeClip(id: removedID)
        await fulfillment(of: [changed], timeout: 1)
        await settle(queue)
        await settle(queue)
        await settle(queue)
        XCTAssertEqual(appPopup.selectedItem?.representedObject as? String, "")
        XCTAssertEqual(table.numberOfRows, 1)
        let remaining = try storage.searchClipSummaries(query: "", appBundleID: "org.test.remaining")
        XCTAssertEqual(remaining.count, table.numberOfRows)
    }

    @MainActor
    func testProgrammaticCloseRejectsPendingReplyAndNewSessionStillWorks() async throws {
        _ = NSApplication.shared
        let queue = DispatchQueue(label: "test.search.close")
        let storage = try Storage(inMemory: true, installStarterContent: false)
        _ = try storage.insert(ClipItem(kind: .text, title: "Fixture", text: "body", createdAt: Date()))
        await settle(queue)
        let controller = HistorySearchPanelController(storage: storage, dataQueue: queue)
        controller.prepare(targetPID: nil, paste: { _, _, _, _ in }, save: { _ in }, open: { _ in })
        let window = try XCTUnwrap(controller.window)
        let table = try XCTUnwrap(descendants(try XCTUnwrap(window.contentView)).compactMap { $0 as? NSTableView }.first)
        queue.sync {}
        window.close()
        await settle(queue)
        XCTAssertEqual(table.numberOfRows, 0)
        controller.prepare(targetPID: nil, paste: { _, _, _, _ in }, save: { _ in }, open: { _ in })
        defer { window.close() }
        await settle(queue)
        XCTAssertEqual(table.numberOfRows, 1)
    }

    func testKeyboardModelMatchesHistoryPasteConventions() {
        XCTAssertEqual(
            HistorySearchKeyboardAction.resolve(keyCode: UInt16(kVK_Return), modifiers: []),
            .pasteOriginal
        )
        XCTAssertEqual(
            HistorySearchKeyboardAction.resolve(keyCode: UInt16(kVK_Return), modifiers: [.shift]),
            .pastePlain
        )
        XCTAssertEqual(
            HistorySearchKeyboardAction.resolve(keyCode: UInt16(kVK_Return), modifiers: [.command]),
            .copyOnly
        )
        XCTAssertEqual(
            HistorySearchKeyboardAction.resolve(keyCode: UInt16(kVK_UpArrow), modifiers: []),
            .moveSelection(-1)
        )
        XCTAssertEqual(
            HistorySearchKeyboardAction.resolve(keyCode: UInt16(kVK_Escape), modifiers: []),
            .dismiss
        )
    }

    func testRequestGateRejectsQueuedStaleSearchesBeforeDatabaseRead() {
        let gate = HistorySearchRequestGate()
        let first = gate.begin()
        let latest = gate.begin()
        XCTAssertFalse(gate.isCurrent(first))
        XCTAssertTrue(gate.isCurrent(latest))
    }

    func testSearchMatchesTitleAndFullTextWithoutOCR() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let older = Date(timeIntervalSinceNow: -8 * 86_400)
        _ = try storage.insert(ClipItem(
            kind: .text, title: "Заявка", text: "Внутри есть уникальный маркер ЖУК-42",
            appBundleID: "com.example.editor", createdAt: older
        ))
        _ = try storage.insert(ClipItem(
            kind: .image, title: "Картинка", data: Data([1, 2, 3]),
            appBundleID: "com.example.editor", createdAt: Date()
        ))
        _ = try storage.insert(ClipItem(
            kind: .text, title: "Other", text: "ordinary",
            appBundleID: "com.example.mail", createdAt: Date()
        ))

        let textResults = try storage.searchClipSummaries(query: "жук-42")
        XCTAssertEqual(textResults.map(\.title), ["Заявка"])
        XCTAssertTrue(try storage.searchClipSummaries(query: "ЖУК-42", kind: .image).isEmpty)

        let editorResults = try storage.searchClipSummaries(query: "", appBundleID: "com.example.editor")
        XCTAssertEqual(editorResults.count, 2)
        let recent = try storage.searchClipSummaries(query: "", createdAfter: Date(timeIntervalSinceNow: -3_600))
        XCTAssertEqual(recent.count, 2)
    }

    func testSearchFiltersKindAndRespectsLimit() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        for index in 0..<5 {
            _ = try storage.insert(ClipItem(
                kind: .text, title: "same \(index)", text: "needle \(index)",
                createdAt: Date(timeIntervalSinceNow: TimeInterval(-index))
            ))
        }
        _ = try storage.insert(ClipItem(
            kind: .file, title: "needle file", text: "/tmp/needle.txt", createdAt: Date()
        ))
        XCTAssertEqual(try storage.searchClipSummaries(query: "needle", kind: .text, limit: 2).count, 2)
        XCTAssertEqual(try storage.searchClipSummaries(query: "needle", kind: .file).count, 1)
        XCTAssertEqual(try storage.searchClipSummaries(query: "").count, 6)
    }

    func testSearchDoesNotHideOlderMatchBehindRecentNonMatches() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let now = Date()
        for index in 0..<3 {
            _ = try storage.insert(ClipItem(
                kind: .text, title: "Recent \(index)", text: "unrelated",
                createdAt: now.addingTimeInterval(-TimeInterval(index))
            ))
        }
        _ = try storage.insert(ClipItem(
            kind: .text, title: "Older match", text: "needle",
            createdAt: now.addingTimeInterval(-100)
        ))

        let results = try storage.searchClipSummaries(query: "needle", limit: 1)
        XCTAssertEqual(results.map(\.title), ["Older match"])
    }

    func testFileClipboardCodecRoundTripsNewlinePathsAndReadsLegacyRows() {
        let urls = [URL(fileURLWithPath: "/tmp/name\nwith-newline.txt")]
        let encoded = FileClipboardCodec.encode(urls)
        XCTAssertNotNil(encoded)
        XCTAssertEqual(FileClipboardCodec.decode(encoded ?? "").map(\.path), urls.map(\.path))
        XCTAssertEqual(
            FileClipboardCodec.decode("/tmp/one.txt\n/tmp/two.txt").map(\.path),
            ["/tmp/one.txt", "/tmp/two.txt"]
        )
    }
}
