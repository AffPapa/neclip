import AppKit
import XCTest
@testable import NeClip

final class MenuSearchCommandTests: XCTestCase {
    @MainActor
    private func event(_ code: UInt16, _ characters: String, modifiers: NSEvent.ModifierFlags = .command,
                       repeat isRepeat: Bool = false) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: 0, windowNumber: 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters,
            isARepeat: isRepeat, keyCode: code
        ))
    }

    @MainActor
    func testRussianPhysicalCommandsReachTheSameCallbacksAsLatin() throws {
        let field = MenuSearchField()
        var commands: [String] = []
        field.onPreviewFirst = { commands.append("preview") }
        field.onTogglePinFirst = { commands.append("pin") }
        field.onSaveFirstAsSnippet = { commands.append("snippet") }
        field.onUndo = { commands.append("undo") }
        field.onOpenFirst = { commands.append("open") }
        for (code, russian, latin) in [(UInt16(14), "у", "e"), (35, "з", "p"), (1, "ы", "s"), (6, "я", "z"), (31, "щ", "o")] {
            field.keyDown(with: try event(code, russian))
            field.keyDown(with: try event(code, latin))
        }
        XCTAssertEqual(commands, ["preview", "preview", "pin", "pin", "snippet", "snippet", "undo", "undo", "open", "open"])
    }

    @MainActor
    func testNumberPositionsRemainPhysicalAndPreservePasteModifiers() throws {
        let field = MenuSearchField()
        var selected: [(Int, NSEvent.ModifierFlags)] = []
        field.onQuickSelect = { selected.append(($0, $1)) }
        XCTAssertTrue(field.handleCommand(try event(18, "!", modifiers: [.command, .shift])))
        XCTAssertTrue(field.handleCommand(try event(25, "(", modifiers: [.command, .option])))
        XCTAssertEqual(selected.map { $0.0 }, [0, 8])
        XCTAssertEqual(selected.map { $0.1 }, [[.command, .shift], [.command, .option]])
    }

    @MainActor
    func testKeyEquivalentDispatchIsLimitedToFocusedSearch() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let field = MenuSearchField(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        let other = NSTextField(frame: NSRect(x: 0, y: 35, width: 200, height: 28))
        window.contentView?.addSubview(field)
        window.contentView?.addSubview(other)
        var previewCount = 0
        field.onPreviewFirst = { previewCount += 1 }
        XCTAssertTrue(window.makeFirstResponder(field))
        XCTAssertTrue(field.performKeyEquivalent(with: try event(14, "у")))
        XCTAssertEqual(previewCount, 1)
        XCTAssertTrue(window.makeFirstResponder(other))
        XCTAssertFalse(field.performKeyEquivalent(with: try event(14, "у")))
        XCTAssertEqual(previewCount, 1)
    }

    @MainActor
    func testTextEditingAndNavigationRemainWithTheirNativeOwners() throws {
        let field = MenuSearchField()
        var undoCount = 0
        var deleteCount = 0
        var previewCount = 0
        var navigateCount = 0
        field.onUndo = { undoCount += 1 }
        field.onDeleteFirst = { deleteCount += 1 }
        field.onPreviewFirst = { previewCount += 1 }
        field.onNavigateToMenu = { navigateCount += 1 }
        field.stringValue = "поиск"
        XCTAssertFalse(field.handleCommand(try event(6, "я")))
        XCTAssertFalse(field.handleCommand(try event(51, "\u{8}")))
        XCTAssertFalse(field.handleCommand(try event(49, " ", modifiers: [])))
        XCTAssertFalse(field.handleCommand(try event(14, "у", modifiers: [])))
        // Native Select All, Copy, Paste, Cut and Redo must not be intercepted.
        for (code, character) in [(UInt16(0), "ф"), (8, "с"), (9, "м"), (7, "ч")] {
            XCTAssertFalse(field.handleCommand(try event(code, character)))
        }
        XCTAssertFalse(field.handleCommand(try event(6, "Я", modifiers: [.command, .shift])))
        XCTAssertFalse(field.handleCommand(try event(14, "у", repeat: true)))
        XCTAssertTrue(field.handleCommand(try event(125, "", modifiers: [])))
        XCTAssertFalse(field.handleCommand(try event(125, "", modifiers: .option)))
        XCTAssertEqual(undoCount, 0)
        XCTAssertEqual(deleteCount, 0)
        XCTAssertEqual(previewCount, 0)
        XCTAssertEqual(navigateCount, 1)
        field.stringValue = ""
        XCTAssertTrue(field.handleCommand(try event(6, "я")))
        XCTAssertTrue(field.handleCommand(try event(51, "\u{8}")))
        XCTAssertTrue(field.handleCommand(try event(49, " ", modifiers: [])))
        XCTAssertEqual(undoCount, 1)
        XCTAssertEqual(deleteCount, 1)
        XCTAssertEqual(previewCount, 1)
    }
}
