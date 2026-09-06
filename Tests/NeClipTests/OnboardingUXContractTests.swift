import Foundation
import XCTest

final class OnboardingUXContractTests: XCTestCase {
    private func source() throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent("Sources/NeClip/OnboardingWindow.swift"),
            encoding: .utf8
        )
    }

    func testIntroductionFocusesOnSelectionAndSnippetFolders() throws {
        let source = try source()
        XCTAssertTrue(source.contains("shortcut(Settings.historyShortcut.displayString"))
        XCTAssertTrue(source.contains("shortcut(\"↑↓ → ↩\""))
        XCTAssertTrue(source.contains("shortcut(Settings.snippetsShortcut.displayString"))
        XCTAssertFalse(source.contains("Settings.manualLayoutShortcut"))
        XCTAssertFalse(source.contains("Settings.disableAutomaticLayoutShortcut"))
    }

    func testShortWindowsKeepActionsOutsideScrollableExplanation() throws {
        let source = try source()
        XCTAssertTrue(source.contains("window.styleMask = [.titled, .resizable]"))
        XCTAssertTrue(source.contains("window.contentMinSize = NSSize(width: 560, height: 420)"))
        XCTAssertTrue(source.contains(".frame(minWidth: 560, minHeight: 420)"))
        XCTAssertFalse(source.contains(".frame(width: 560, height: 540)"))
        let layout = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        XCTAssertTrue(layout.contains("""
        ScrollView {
        introduction
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(26)
        }
        Divider()
        actions
        """))
        XCTAssertTrue(source.contains(".fixedSize(horizontal: false, vertical: true)"))
    }

    func testPermissionActionsRemainExplicitAndContinuingRemainsPossible() throws {
        let source = try source()
        XCTAssertTrue(source.contains("requestAutoPaste: { PasteService.requestAccessibility() }"))
        XCTAssertTrue(source.contains("Button(\"Разрешить автовставку…\", action: requestAutoPaste)"))
        XCTAssertTrue(source.contains("Button(\"Открыть конфиденциальность…\", action: openClipboardPrivacy)"))
        XCTAssertTrue(source.contains("Button(clipboardAccess == .denied ? \"Продолжить без истории\" : \"Начать работу\", action: complete)"))
        XCTAssertTrue(source.contains(".keyboardShortcut(.defaultAction)"))
        XCTAssertTrue(source.contains("Автовставка — по желанию"))
        XCTAssertTrue(source.contains("NSApplication.didBecomeActiveNotification"))
        XCTAssertTrue(source.contains("accessibilityTrusted = PasteService.isAccessibilityTrusted"))
        XCTAssertTrue(source.contains("clipboardAccess = ClipboardAccess.current"))
    }

    func testPermissionStatusAndShortcutRowsHaveCombinedAccessibilityLabels() throws {
        let source = try source()
        XCTAssertEqual(source.components(separatedBy: ".accessibilityElement(children: .combine)").count - 1, 2)
        XCTAssertEqual(source.components(separatedBy: ".accessibilityHidden(true)").count - 1, 2)
    }
}
