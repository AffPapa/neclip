import AppKit
import SwiftUI

/// A dedicated native editor keeps selection and undo scoped to one snippet.
@MainActor
final class SnippetTextView: NSTextView {
    private let documentUndo = UndoManager()
    var snippetID: Int64?
    var onChange: ((String) -> Void)?
    override var undoManager: UndoManager? { documentUndo }

    @objc func undo(_ sender: Any?) { documentUndo.undo() }
    @objc func redo(_ sender: Any?) { documentUndo.redo() }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(undo(_:)) { return documentUndo.canUndo }
        if item.action == #selector(redo(_:)) { return documentUndo.canRedo }
        return super.validateUserInterfaceItem(item)
    }

    override func didChangeText() {
        super.didChangeText()
        onChange?(string)
    }

    func synchronize(with model: SnippetsEditorModel) {
        if snippetID != model.selectedSnippetID {
            documentUndo.removeAllActions()
            snippetID = model.selectedSnippetID
            string = model.editorContent
            setSelectedRange(NSRange(location: 0, length: 0))
        } else if string != model.editorContent {
            documentUndo.removeAllActions()
            string = model.editorContent
        }
        model.contentTextView = self
    }

    static func make(model: SnippetsEditorModel) -> SnippetTextView {
        let view = SnippetTextView(frame: .zero)
        view.isRichText = false
        view.importsGraphics = false
        view.allowsUndo = true
        view.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        view.textContainerInset = NSSize(width: 5, height: 5)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        view.setAccessibilityLabel("Текст сниппета")
        view.onChange = { [weak model, weak view] text in
            guard let model, let view, view.snippetID == model.selectedSnippetID else { return }
            model.editorContent = text
        }
        view.synchronize(with: model)
        return view
    }
}

struct SnippetTextEditor: NSViewRepresentable {
    @ObservedObject var model: SnippetsEditorModel

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = SnippetTextView.make(model: model)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        (scroll.documentView as? SnippetTextView)?.synchronize(with: model)
    }
}
