import AppKit
import SwiftUI
import XCTest
@testable import NeClip

final class RemainingAuditTests: XCTestCase {
    @MainActor
    func testTokenInsertionUsesNativeSelectionAndUndo() throws {
        _ = NSApplication.shared
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let id = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "A", content: "Привет 👋 мир")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: id)
        let view = SnippetTextView.make(model: model)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.makeFirstResponder(view)
        defer { window.close() }
        for location in [0, 7, (view.string as NSString).length] {
            view.setSelectedRange(NSRange(location: location, length: 0))
            let before = view.string
            view.undoManager?.beginUndoGrouping()
            model.insertToken(.date)
            view.undoManager?.endUndoGrouping()
            XCTAssertEqual(view.string, (before as NSString).replacingCharacters(in: NSRange(location: location, length: 0), with: "{date}"))
            XCTAssertEqual(model.editorContent, view.string)
            let undo = NSMenuItem(title: "Undo", action: #selector(SnippetTextView.undo(_:)), keyEquivalent: "z")
            XCTAssertTrue(view.validateUserInterfaceItem(undo))
            XCTAssertTrue(view.responds(to: undo.action!))
            view.undo(nil)
            XCTAssertEqual(view.string, before)
            view.redo(nil)
            XCTAssertTrue(view.string.contains("{date}"))
            view.undoManager?.undo()
        }
        view.setSelectedRange((view.string as NSString).range(of: "👋"))
        model.insertToken(.clipboard)
        XCTAssertEqual(view.string, "Привет {clipboard} мир")
        model.editorChanged()
        XCTAssertTrue(model.flushPendingSave())
        XCTAssertEqual(try storage.fetchSnippet(id: id)?.content, view.string)
        let selection = view.selectedRange()
        view.synchronize(with: model)
        XCTAssertEqual(view.selectedRange(), selection, "Autosave must not move the caret")
    }

    @MainActor
    func testSwitchingSnippetClearsOnlyItsEditorUndo() throws {
        _ = NSApplication.shared
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let a = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "A", content: "A")?.id)
        let b = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "B", content: "B")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: a)
        let view = SnippetTextView.make(model: model)
        model.insertToken(.date)
        XCTAssertTrue(view.undoManager?.canUndo == true)
        XCTAssertTrue(model.openSnippet(id: b))
        // A stale editor cannot insert into a newly selected document.
        model.insertToken(.clipboard)
        XCTAssertEqual(model.editorContent, "B")
        view.insertText("late old document event", replacementRange: view.selectedRange())
        XCTAssertEqual(model.editorContent, "B")
        view.synchronize(with: model)
        XCTAssertEqual(view.string, "B")
        XCTAssertFalse(view.undoManager?.canUndo == true)
        model.insertToken(.date)
        XCTAssertTrue(view.undoManager?.canUndo == true)
        model.editorContent = "External replacement"
        view.synchronize(with: model)
        XCTAssertEqual(view.string, "External replacement")
        XCTAssertFalse(view.undoManager?.canUndo == true)
    }

    @MainActor
    func testHostedEditorTracksDocumentSwitchAndExternalContent() async throws {
        _ = NSApplication.shared
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let a = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "A", content: "A")?.id)
        let b = try XCTUnwrap(storage.addSnippet(folderID: nil, title: "B", content: "B")?.id)
        let model = SnippetsEditorModel(storage: storage)
        model.reload(selecting: a)
        let hosting = NSHostingView(rootView: SnippetTextEditor(model: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        defer { window.close() }
        hosting.layoutSubtreeIfNeeded()
        let view = try XCTUnwrap(model.contentTextView)
        model.insertToken(.date)
        XCTAssertTrue(model.openSnippet(id: b))
        for _ in 0..<100 where view.string != "B" || view.snippetID != b {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(view.string, "B")
        XCTAssertEqual(view.snippetID, b)
        XCTAssertFalse(view.undoManager?.canUndo == true)
        model.editorContent = "Changed externally"
        for _ in 0..<100 where view.string != "Changed externally" {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(view.string, "Changed externally")
    }

    func testLiteralAndEscapedTemplatesNeverReadClipboardForRendering() throws {
        for template in ["literal", "{date}", "{{clipboard}}", "{{{clipboard}}}"] {
            let value = try SnippetClipboardRead.readIfNeeded(template: template, expectedGeneration: 7,
                readGeneration: { XCTFail("Unexpected generation read"); return 7 },
                readText: { XCTFail("Unexpected clipboard materialization"); return "synthetic" })
            XCTAssertNil(value)
        }
        var reads = 0
        let value = try SnippetClipboardRead.readIfNeeded(template: "{{clipboard}}{clipboard}", expectedGeneration: 7,
            readGeneration: { 7 }, readText: { reads += 1; return "synthetic" })
        XCTAssertEqual(value, "synthetic")
        XCTAssertEqual(reads, 1)
    }

    func testClipboardExpansionRejectsGenerationChangesBeforeAndDuringRead() throws {
        XCTAssertThrowsError(try SnippetClipboardRead.readIfNeeded(template: "{clipboard}", expectedGeneration: 7,
            readGeneration: { 8 }, readText: { XCTFail("Stale generation read"); return nil }))
        var generation = 7
        XCTAssertThrowsError(try SnippetClipboardRead.readIfNeeded(template: "{clipboard}", expectedGeneration: 7,
            readGeneration: { generation }, readText: { generation = 8; return "synthetic" }))
        XCTAssertNil(try SnippetClipboardRead.readIfNeeded(template: "{clipboard}", expectedGeneration: 7,
            readGeneration: { 7 }, readText: { nil }))
    }

}
