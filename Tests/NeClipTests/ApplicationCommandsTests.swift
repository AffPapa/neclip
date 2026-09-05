import AppKit
import XCTest
@testable import NeClip

final class ApplicationCommandsTests: XCTestCase {
    @MainActor
    func testCloseCommandUsesNativeResponderChainAndCommandW() throws {
        let menu = AppDelegate.makeFileMenu(
            historyShortcut: .historyDefault, snippetsShortcut: .snippetsDefault, target: NSObject()
        )
        let close = try XCTUnwrap(menu.items.last)
        XCTAssertEqual(close.title, "Закрыть окно")
        XCTAssertEqual(close.action, #selector(NSWindow.performClose(_:)))
        XCTAssertEqual(close.keyEquivalent, "w")
        XCTAssertEqual(close.keyEquivalentModifierMask, [.command])
        XCTAssertNil(close.target)
        XCTAssertTrue(menu.autoenablesItems)
    }

    @MainActor
    func testFileMenuReflectsConfiguredShortcutsAndTargetsAppDelegate() throws {
        let target = NSObject()
        let history = ShortcutDescriptor(keyCode: 4, modifiers: [.control, .option])
        let snippets = ShortcutDescriptor(keyCode: 40, modifiers: [.command, .option])
        let menu = AppDelegate.makeFileMenu(
            historyShortcut: history, snippetsShortcut: snippets, target: target
        )
        let historyItem = try XCTUnwrap(menu.item(at: 0))
        let snippetsItem = try XCTUnwrap(menu.item(at: 1))
        XCTAssertEqual(historyItem.title, "Открыть историю")
        XCTAssertEqual(historyItem.keyEquivalent, history.keyEquivalent)
        XCTAssertEqual(historyItem.keyEquivalentModifierMask, history.nsEventModifiers)
        XCTAssertTrue(historyItem.target === target)
        XCTAssertNotNil(historyItem.action)
        XCTAssertEqual(snippetsItem.title, "Открыть папки сниппетов")
        XCTAssertEqual(snippetsItem.keyEquivalent, snippets.keyEquivalent)
        XCTAssertEqual(snippetsItem.keyEquivalentModifierMask, snippets.nsEventModifiers)
        XCTAssertTrue(snippetsItem.target === target)
        XCTAssertNotNil(snippetsItem.action)
    }

    @MainActor
    func testEscapeLeavesFocusedTextAndShortcutRecorderInControl() {
        XCTAssertFalse(PreferencesWindowController.allowsEscapeClose(firstResponder: NSTextView()))
        XCTAssertFalse(PreferencesWindowController.allowsEscapeClose(firstResponder: NSTextField()))
        XCTAssertFalse(PreferencesWindowController.allowsEscapeClose(firstResponder: ShortcutRecorderButton()))
        XCTAssertTrue(PreferencesWindowController.allowsEscapeClose(firstResponder: NSView()))
        XCTAssertTrue(PreferencesWindowController.allowsEscapeClose(firstResponder: nil))
    }
}
