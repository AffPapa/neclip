import Foundation
import XCTest

final class MenuSimplificationContractTests: XCTestCase {
    private func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent("Sources/NeClip/StatusBarController.swift"), encoding: .utf8)
    }

    func testBothRootsUseFoldersWithoutDuplicatedQuickListOrImplicitTopTarget() throws {
        let source = try source()
        XCTAssertEqual(source.components(separatedBy: "appendSnippetFolders(to: menu)").count - 1, 2)
        for retired in ["topEntry", "UndoDeletion", "firstResultActionsItem", "textTransformMenuItem",
                        "quickPasteSnippet", "Быстрый доступ", "Папки сниппетов"] {
            XCTAssertFalse(source.contains(retired), "Retired menu behavior: \(retired)")
        }
        let start = try XCTUnwrap(source.range(of: "private func buildSnippetsMenu()"))
        let end = try XCTUnwrap(source.range(of: "/// Shared by initial", range: start.upperBound..<source.endIndex))
        let snippetsRoot = String(source[start.lowerBound..<end.lowerBound])
        XCTAssertTrue(snippetsRoot.contains("appendSnippetFolders(to: menu)"))
        XCTAssertTrue(snippetsRoot.contains("Self.appendStandardFooter(to: menu, target: self)"))
        XCTAssertEqual(snippetsRoot.components(separatedBy: "#selector(openSnippetsEditor)").count - 1, 1)
        XCTAssertFalse(snippetsRoot.contains("utilityMenuItem"))
    }

    func testOptionNoLongerOpensAHistoryInspector() throws {
        let source = try source()
        let start = try XCTUnwrap(source.range(of: "private func pasteClip(_ sender:"))
        let end = try XCTUnwrap(source.range(of: "@objc private func toggleAutomaticLayoutCorrection", range: start.upperBound..<source.endIndex))
        let paste = String(source[start.lowerBound..<end.lowerBound])
        XCTAssertFalse(paste.contains("if modifiers.contains(.option)"))
        XCTAssertFalse(paste.contains("HistoryItemInspectorWindowController"))
        XCTAssertFalse(paste.contains("optionOverride"))
        XCTAssertTrue(paste.contains("modifiers.contains(.shift)"))
        XCTAssertTrue(paste.contains("modifiers.contains(.control)"))
        XCTAssertTrue(paste.contains("modifiers.contains(.command)"))
        XCTAssertTrue(paste.contains("forcedModifiers: NSEvent.ModifierFlags?"))
        XCTAssertTrue(source.contains("NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags"))
        XCTAssertTrue(source.contains("forcedModifiers: actionModifiers.subtracting(.command)"))
        XCTAssertTrue(source.contains("let copyOnly = actionModifiers.contains(.command)"))
    }

    func testHistoryIsOneUnifiedListAndSnippetPasteDoesNotReorderTheLibrary() throws {
        let source = try source()
        XCTAssertFalse(source.contains("if !pinned.isEmpty"))
        XCTAssertFalse(source.contains("Ранее закреплённые"))
        XCTAssertFalse(source.contains("⌥ клик — просмотр и открепление"))
        XCTAssertFalse(source.contains("summaries(limit: 101, pinnedOnly: true)"))
        XCTAssertFalse(source.contains("Storage.shared.setPinned"))
        XCTAssertFalse(source.contains("Storage.shared.setSnippetPinned"))
        XCTAssertFalse(source.contains("Storage.shared.markSnippetUsed"))
        XCTAssertTrue(source.contains("Storage.shared.fetchSnippet(id: id)"))
        XCTAssertTrue(source.contains("SnippetRenderer.render(snippet.content, clipboard: clipboard)"))
    }
}
