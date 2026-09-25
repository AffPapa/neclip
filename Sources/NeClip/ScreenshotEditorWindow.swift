import AppKit

@MainActor
final class ScreenshotEditorWindowController: NSWindowController, NSWindowDelegate {
    var onCopy: ((Data) -> Void)?
    var onClose: (() -> Void)?
    private let canvas: ScreenshotCanvas
    private let composition: ScreenshotCompositionView
    private let resolutionReduced: Bool
    private let pasteboard: NSPasteboard
    private let copyButton = NSButton(title: "Копировать", target: nil, action: nil)
    private let saveButton = NSButton(title: "Сохранить…", target: nil, action: nil)
    private let undoButton = NSButton(title: "Отменить", target: nil, action: nil)
    private let redoButton = NSButton(title: "Повторить", target: nil, action: nil)
    private let status = NSTextField(labelWithString: "Готово")
    private var exporting = false
    private var completed = false
    private var toolButtons: [NSButton] = []
    private var savePanel: NSSavePanel?
    private let scroll = NSScrollView()
    private let scale = NSPopUpButton()
    private let color = NSPopUpButton()
    private let background = NSPopUpButton()

    init(image: CGImage, pasteboard: NSPasteboard = .general, preferredScreen: NSScreen? = nil, resolutionReduced: Bool = false) {
        self.resolutionReduced = resolutionReduced
        canvas = ScreenshotCanvas(image: image)
        composition = ScreenshotCompositionView(canvas: canvas)
        self.pasteboard = pasteboard
        let aspect = CGFloat(image.width) / CGFloat(max(image.height, 1))
        let visibleFrame = (preferredScreen ?? NSScreen.main)?.visibleFrame.insetBy(dx: 80, dy: 80)
        let visible = visibleFrame?.size
            ?? CGSize(width: 1100, height: 760)
        let maximumHeight = min(860, visible.height)
        let maximumWidth = min(1280, visible.width)
        let initialWidth = min(maximumWidth, max(660, maximumWidth * 0.82))
        let initialHeight = min(maximumHeight, max(380, initialWidth / aspect + 84))
        let window = NSWindow(contentRect: CGRect(origin: .zero,
                                                   size: CGSize(width: initialWidth, height: initialHeight)),
                              styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init(window: window)
        if let visibleFrame {
            let x = visibleFrame.midX - initialWidth / 2
            let y = visibleFrame.midY - initialHeight / 2
            window.setFrameOrigin(CGPoint(x: x, y: y))
        }
        window.title = "Скриншот · \(image.width) × \(image.height)"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        // The canvas must receive drag events for drawing annotations. Moving
        // the window from its background steals those events and makes a pen
        // stroke drag the entire editor instead.
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.minSize = CGSize(width: 660, height: 380)
        window.delegate = self
        RuntimeIdentity.configurePreviewWindow(window)
        let tools = NSStackView()
        tools.spacing = 6
        for (index, tool) in ScreenshotTool.allCases.enumerated() {
            let button = NSButton(image: NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: tool.rawValue)!,
                                  target: self, action: #selector(selectTool(_:)))
            button.tag = index
            button.setButtonType(.pushOnPushOff)
            button.bezelStyle = .texturedRounded
            button.imageScaling = .scaleProportionallyDown
            button.setAccessibilityLabel(tool.rawValue)
            button.toolTip = tool == .redact ? "Непрозрачная заливка. Надёжнее размытия." : tool.rawValue
            button.state = tool == .redact ? .on : .off
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            tools.addArrangedSubview(button)
            toolButtons.append(button)
        }
        scale.addItems(withTitles: ["По размеру", "100%", "200%"])
        scale.setAccessibilityLabel("Масштаб снимка")
        scale.target = self
        scale.action = #selector(changeScale(_:))
        tools.addArrangedSubview(NSView())
        scale.widthAnchor.constraint(equalToConstant: 96).isActive = true
        tools.addArrangedSubview(scale)
        color.addItems(withTitles: ScreenshotMarkupColor.allCases.map(\.rawValue))
        color.selectItem(at: ScreenshotMarkupColor.allCases.firstIndex(of: .red) ?? 0)
        color.setAccessibilityLabel("Цвет пометок")
        color.toolTip = "Цвет пометок"
        color.target = self
        color.action = #selector(changeColor(_:))
        color.widthAnchor.constraint(equalToConstant: 100).isActive = true
        tools.addArrangedSubview(color)
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.allowsMagnification = true
        scroll.minMagnification = 0.05
        scroll.maxMagnification = 4
        scroll.contentView = ScreenshotClipView()
        scroll.documentView = composition
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .underPageBackgroundColor
        let actions = NSStackView(views: [undoButton, redoButton, NSView(), saveButton, copyButton])
        actions.spacing = 8
        let actionSymbols: [(NSButton, String, String)] = [
            (undoButton, "arrow.uturn.backward", "Отменить"),
            (redoButton, "arrow.uturn.forward", "Повторить"),
            (saveButton, "square.and.arrow.down", "Сохранить"),
            (copyButton, "doc.on.doc", "Копировать")
        ]
        for (button, symbol, label) in actionSymbols {
            button.target = self
            button.bezelStyle = .texturedRounded
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
            button.title = ""
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel(label)
            button.toolTip = label
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
        }
        copyButton.action = #selector(copyImage)
        copyButton.keyEquivalent = "\r"
        copyButton.keyEquivalentModifierMask = [.command]
        saveButton.action = #selector(saveImage)
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = [.command]
        undoButton.action = #selector(undoEdit)
        undoButton.keyEquivalent = "z"
        undoButton.keyEquivalentModifierMask = [.command]
        redoButton.action = #selector(redoEdit)
        redoButton.keyEquivalent = "z"
        redoButton.keyEquivalentModifierMask = [.command, .shift]
        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        status.textColor = .secondaryLabelColor
        status.maximumNumberOfLines = 3
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        background.addItems(withTitles: ScreenshotPresentation.allCases.map(\.rawValue))
        background.setAccessibilityLabel("Оформление снимка")
        background.toolTip = "Фон и отступ без изменения исходных пикселей"
        background.target = self
        background.action = #selector(changeBackground(_:))
        let root = NSVisualEffectView()
        root.material = .windowBackground
        root.blendingMode = .behindWindow
        root.state = .active
        window.contentView = root
        let toolbar = NSVisualEffectView()
        toolbar.material = .headerView
        toolbar.blendingMode = .withinWindow
        toolbar.state = .active
        toolbar.wantsLayer = true
        toolbar.layer?.cornerRadius = 10
        toolbar.layer?.masksToBounds = true
        for view in [scroll, toolbar] {
            root.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        toolbar.addSubview(tools)
        toolbar.addSubview(actions)
        toolbar.addSubview(status)
        toolbar.addSubview(background)
        for view in [tools, actions, status, background] { view.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: root.topAnchor, constant: 32),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: toolbar.topAnchor, constant: -10),
            toolbar.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            toolbar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            toolbar.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            toolbar.heightAnchor.constraint(equalToConstant: 84),
            tools.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 8),
            tools.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 8),
            actions.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -8),
            actions.topAnchor.constraint(equalTo: toolbar.topAnchor, constant: 8),
            tools.trailingAnchor.constraint(lessThanOrEqualTo: actions.leadingAnchor, constant: -8),
            status.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor, constant: 8),
            status.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            status.trailingAnchor.constraint(lessThanOrEqualTo: background.leadingAnchor, constant: -12),
            background.trailingAnchor.constraint(equalTo: toolbar.trailingAnchor, constant: -8),
            background.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor, constant: -8),
            background.widthAnchor.constraint(equalToConstant: 155)
        ])
        canvas.onChange = { [weak self] in self?.refresh() }
        canvas.onLimit = { [weak self] in
            self?.status.stringValue = "Лимит 128 пометок. Отмените одну, чтобы добавить новую."
            self?.status.textColor = .systemRed
        }
        canvas.onCancel = { [weak window] in window?.performClose(nil) }
        canvas.onTextCommitted = { [weak self] point, text, markupColor in
            self?.canvas.edits.append(ScreenshotAnnotation(tool: .text, points: [point], text: text, color: markupColor))
            self?.refresh()
        }
        canvas.onToolRequested = { [weak self] index in self?.selectTool(at: index) }
        if visibleFrame == nil { window.center() }
        root.layoutSubtreeIfNeeded()
        // The canvas owns the current color. Re-apply it after AppKit has
        // finished constructing the popup so the visible choice cannot drift
        // from the color used for the first annotation.
        color.selectItem(withTitle: canvas.annotationColor.rawValue)
        changeScale(scale)
        window.makeFirstResponder(canvas)
        refresh()
    }
    required init?(coder: NSCoder) { nil }

    @objc private func selectTool(_ sender: NSButton) {
        selectTool(at: sender.tag)
    }
    private func selectTool(at index: Int) {
        guard ScreenshotTool.allCases.indices.contains(index) else { return }
        canvas.tool = ScreenshotTool.allCases[index]
        for button in toolButtons { button.state = button.tag == index ? .on : .off }
        window?.makeFirstResponder(canvas)
    }
    @objc private func changeColor(_ sender: NSPopUpButton) {
        guard ScreenshotMarkupColor.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        canvas.annotationColor = ScreenshotMarkupColor.allCases[sender.indexOfSelectedItem]
        window?.makeFirstResponder(canvas)
    }
    @objc private func changeBackground(_ sender: NSPopUpButton) {
        guard !exporting, ScreenshotPresentation.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        canvas.commitPendingText()
        composition.presentation = ScreenshotPresentation.allCases[sender.indexOfSelectedItem]
        changeScale(scale)
        refresh()
        window?.makeFirstResponder(canvas)
    }
    @objc private func undoEdit() { canvas.edits.undo(); refresh() }
    @objc private func redoEdit() { canvas.edits.redo(); refresh() }

    @objc private func changeScale(_ sender: NSPopUpButton) {
        guard scroll.documentView != nil else { return }
        let fit = ScreenshotRenderer.fittingMagnification(
            contentSize: scroll.contentSize,
            imageSize: composition.frame.size,
            backingScale: window?.backingScaleFactor ?? 1,
            maximum: scroll.maxMagnification
        )
        // One document unit is an image pixel, not an AppKit point. At 100%,
        // one image pixel must occupy one display pixel on Retina as well.
        scroll.magnification = sender.indexOfSelectedItem == 0 ? max(scroll.minMagnification, fit)
            : CGFloat(sender.indexOfSelectedItem) / (window?.backingScaleFactor ?? 1)
    }

    func windowDidResize(_ notification: Notification) {
        if scale.indexOfSelectedItem == 0 { changeScale(scale) }
    }
    func windowDidChangeBackingProperties(_ notification: Notification) { changeScale(scale) }

    private func refresh() {
        completed = false
        canvas.needsDisplay = true
        status.textColor = .secondaryLabelColor
        canvas.isEditingEnabled = !exporting
        undoButton.isEnabled = !exporting && !canvas.edits.annotations.isEmpty
        redoButton.isEnabled = !exporting && !canvas.edits.undone.isEmpty
        copyButton.isEnabled = !exporting
        saveButton.isEnabled = !exporting
        background.isEnabled = !exporting
        color.isEnabled = !exporting
        let size = composition.frame.size
        status.stringValue = "\(Int(size.width)) × \(Int(size.height)) пикс."
            + (resolutionReduced ? " · Уменьшено до лимита 32 Мп" : "")
        for button in toolButtons { button.isEnabled = !exporting }
    }

    @objc private func copyImage() {
        let pasteboard = pasteboard
        let generation = pasteboard.changeCount
        export(format: .png) { [weak self] data in
            try ScreenshotClipboard.write(data, to: pasteboard, expectedChangeCount: generation)
            self?.onCopy?(data)
        }
    }

    @objc private func saveImage() {
        guard !exporting, let window else { return }
        let panel = makeSavePanel(format: Settings.screenshotFormat)
        let folder = ScreenshotFolder.url
        let folderAccess = folder?.startAccessingSecurityScopedResource() == true
        panel.directoryURL = folder
        panel.beginSheetModal(for: window) { [weak self] response in
            defer {
                if folderAccess { folder?.stopAccessingSecurityScopedResource() }
                self?.savePanel = nil
            }
            guard response == .OK, let url = panel.url,
                  let popup = panel.accessoryView as? NSPopUpButton,
                  ScreenshotFormat.allCases.indices.contains(popup.indexOfSelectedItem) else { return }
            self?.export(format: ScreenshotFormat.allCases[popup.indexOfSelectedItem], fileURL: url)
        }
    }

    func makeSavePanel(format selected: ScreenshotFormat) -> NSSavePanel {
        let panel = NSSavePanel()
        savePanel = panel
        panel.title = "Сохранить скриншот"
        panel.nameFieldStringValue = "Скриншот-\(Date().formatted(.iso8601).replacingOccurrences(of: ":", with: "-"))-\(UUID().uuidString.prefix(4)).\(selected.suffix)"
        panel.allowedContentTypes = [selected.type]
        panel.canCreateDirectories = true
        let format = NSPopUpButton(frame: CGRect(x: 0, y: 0, width: 200, height: 26))
        format.addItems(withTitles: ScreenshotFormat.allCases.map(\.rawValue))
        format.selectItem(at: ScreenshotFormat.allCases.firstIndex(of: selected) ?? 0)
        format.setAccessibilityLabel("Формат сохранения снимка")
        format.target = self
        format.action = #selector(changeSaveFormat(_:))
        panel.accessoryView = format
        return panel
    }

    @objc private func changeSaveFormat(_ sender: NSPopUpButton) {
        guard let panel = savePanel,
              ScreenshotFormat.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        let format = ScreenshotFormat.allCases[sender.indexOfSelectedItem]
        panel.allowedContentTypes = [format.type]
        panel.nameFieldStringValue = (panel.nameFieldStringValue as NSString).deletingPathExtension + "." + format.suffix
    }

    private func export(format: ScreenshotFormat, fileURL: URL? = nil,
                        publish: ((Data) throws -> Void)? = nil) {
        guard !exporting else { return }
        // Key equivalents can invoke export while the field editor still owns
        // focus. Commit its draft before freezing the annotation array.
        canvas.commitPendingText()
        ScreenshotMetrics.mark("export-start")
        exporting = true
        refresh()
        status.stringValue = "Подготовка…"
        let image = canvas.image, annotations = canvas.edits.annotations
        let presentation = composition.presentation
        Task { [weak self] in
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try ScreenshotRenderer.encode(image, annotations: annotations, format: format, presentation: presentation)
                }.value
                // Hiding the app does not cancel an export the user already
                // requested. The result must still reach its file or the
                // configured pasteboard, and the editor must leave exporting.
                guard let self, let window = self.window else { return }
                if let fileURL {
                    try await Task.detached(priority: .userInitiated) {
                        try ScreenshotFileExport.write(data, to: fileURL)
                    }.value
                    Settings.screenshotFormat = format
                } else { try publish?(data) }
                ScreenshotMetrics.mark("export-finished")
                exporting = false
                completed = true
                window.close()
            } catch {
                guard let self else { return }
                exporting = false
                refresh()
                status.stringValue = (error as? ScreenshotFailure)?.errorDescription
                    ?? "Не удалось сохранить снимок. Проверьте папку и повторите попытку."
                status.textColor = .systemRed
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !exporting else { return false }
        canvas.commitPendingText()
        guard !completed, !canvas.edits.annotations.isEmpty || composition.presentation != .original else { return true }
        let alert = NSAlert()
        alert.messageText = "Закрыть без сохранения?"
        alert.informativeText = "Снимок и пометки будут удалены из памяти."
        alert.addButton(withTitle: "Продолжить редактирование")
        alert.addButton(withTitle: "Закрыть")
        return alert.runModal() == .alertSecondButtonReturn
    }
    func windowWillClose(_ notification: Notification) { onClose?() }
}

@MainActor
final class ScreenshotClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var result = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return result }
        if result.width > documentView.frame.width {
            result.origin.x = (documentView.frame.width - result.width) / 2
        }
        if result.height > documentView.frame.height {
            result.origin.y = (documentView.frame.height - result.height) / 2
        }
        return result
    }
}

@MainActor
final class ScreenshotCompositionView: NSView {
    let canvas: ScreenshotCanvas
    var presentation: ScreenshotPresentation = .original { didSet { updateGeometry() } }
    override var isFlipped: Bool { true }
    init(canvas: ScreenshotCanvas) {
        self.canvas = canvas
        super.init(frame: canvas.frame)
        addSubview(canvas)
        updateGeometry()
    }
    required init?(coder: NSCoder) { nil }
    private func updateGeometry() {
        let inset = CGFloat(presentation.padding(width: canvas.image.width, height: canvas.image.height))
        canvas.setFrameOrigin(CGPoint(x: inset, y: inset))
        setFrameSize(presentation.size(width: canvas.image.width, height: canvas.image.height))
        needsDisplay = true
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        presentation.drawBackground(in: context, width: canvas.image.width, height: canvas.image.height)
        context.restoreGState()
    }
}

@MainActor
enum ScreenshotClipboard {
    static func write(_ png: Data, to pasteboard: NSPasteboard, expectedChangeCount: Int) throws {
        guard pasteboard.changeCount == expectedChangeCount else { throw ScreenshotFailure.clipboardChanged }
        let item = NSPasteboardItem()
        guard item.setData(png, forType: .png) else { throw ScreenshotFailure.clipboardWriteFailed }
        pasteboard.clearContents()
        guard pasteboard.writeObjects([item]) else { throw ScreenshotFailure.clipboardWriteFailed }
        if pasteboard.name == NSPasteboard.general.name {
            ClipboardWriteGuard.shared.markOwnWrite(changeCount: pasteboard.changeCount)
        }
    }
}

@MainActor
enum ScreenshotFolder {
    private static let key = "screenshotFolderBookmark.v1"
    static var url: URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withSecurityScope],
                        relativeTo: nil, bookmarkDataIsStale: &stale)
    }
    static func choose() throws -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Папка для скриншотов"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = url
        guard panel.runModal() == .OK, let selected = panel.url else { return nil }
        let data = try selected.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: key)
        return selected
    }
}

@MainActor
private final class ScreenshotInlineTextField: NSTextField, NSTextFieldDelegate {
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    private var finished = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        delegate = self
    }
    required init?(coder: NSCoder) { nil }

    func commit() {
        guard !finished else { return }
        // Enter arrives through AppKit's shared field editor, before its text
        // necessarily reaches stringValue. Capture that live draft first.
        let value = currentEditor()?.string ?? stringValue
        finished = true
        onCommit?(value)
    }

    func cancel() {
        guard !finished else { return }
        finished = true
        onCancel?()
    }

    // A text field resigns first responder when editing STARTS and AppKit
    // transfers focus to its NSTextView field editor. Only editing-end and
    // field-editor commands represent a user's commit/cancel operation.
    func controlTextDidEndEditing(_ notification: Notification) {
        commit()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            commit()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            cancel()
            return true
        default:
            return false
        }
    }
}

@MainActor
final class ScreenshotCanvas: NSView, NSUserInterfaceValidations {
    let image: CGImage
    var edits = ScreenshotEdits()
    var tool = ScreenshotTool.redact {
        didSet { updateRegionAccessibility(announce: false) }
    }
    var isEditingEnabled = true
    var onChange: (() -> Void)?
    var onLimit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onTextCommitted: ((CGPoint, String, ScreenshotMarkupColor) -> Void)?
    var onToolRequested: ((Int) -> Void)?
    var annotationColor: ScreenshotMarkupColor = .red
    private var draft: ScreenshotAnnotation?
    private var textEntry: ScreenshotInlineTextField?
    private var keyboardRegion = CGRect.zero
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    init(image: CGImage) {
        self.image = image
        super.init(frame: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        ScreenshotRegionAccessibility.configure(self, label: "Разметка снимка",
                                                confirmName: "Создать область или добавить пометку",
                                                adjust: { [weak self] dx, dy, resize in
            self?.adjustKeyboardRegion(dx: dx, dy: dy, resizing: resize) ?? false
        }, confirm: { [weak self] in self?.accessibilityPerformPress() ?? false })
        updateRegionAccessibility(announce: false)
    }
    required init?(coder: NSCoder) { nil }
    func commitPendingText() { textEntry?.commit() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func keyDown(with event: NSEvent) {
        if let delta = ScreenshotKeyboardRegion.delta(for: event, flipped: true) {
            // Shift+Up/Down grows/shrinks height in the same way as capture.
            let resizing = event.modifierFlags.contains(.shift)
            _ = adjustKeyboardRegion(dx: delta.x, dy: resizing ? -delta.y : delta.y, resizing: resizing)
            return
        }
        guard event.modifierFlags.intersection([.command, .control]).isEmpty else {
            super.keyDown(with: event); return
        }
        if event.keyCode == 53 { onCancel?(); return }
        if event.keyCode == 36 || event.keyCode == 76 { _ = accessibilityPerformPress(); return }
        if let value = event.charactersIgnoringModifiers.flatMap({ Int($0) }), (1...5).contains(value) {
            onToolRequested?(value - 1)
            return
        }
        super.keyDown(with: event)
    }

    private func adjustKeyboardRegion(dx: CGFloat, dy: CGFloat, resizing: Bool) -> Bool {
        guard isEditingEnabled else { return false }
        keyboardRegion = ScreenshotKeyboardRegion.adjusted(keyboardRegion, dx: dx, dy: dy, resizing: resizing, in: bounds)
        scrollToVisible(keyboardRegion)
        needsDisplay = true
        updateRegionAccessibility()
        return true
    }

    override func accessibilityPerformPress() -> Bool {
        guard isEditingEnabled else { return false }
        if keyboardRegion.isEmpty { return adjustKeyboardRegion(dx: 0, dy: 0, resizing: false) }
        // Match the mouse path: a keyboard/VoiceOver action must not discard a
        // live text draft when it starts the next annotation.
        textEntry?.commit()
        guard edits.annotations.count < ScreenshotEdits.maximumAnnotations else { onLimit?(); return false }
        let point = keyboardRegion.origin
        if tool == .text { beginTextEntry(at: point) }
        else {
            edits.append(ScreenshotAnnotation(tool: tool,
                points: [point, CGPoint(x: keyboardRegion.maxX, y: keyboardRegion.maxY)], color: annotationColor))
            onChange?()
            needsDisplay = true
            ScreenshotRegionAccessibility.announce("Добавлена пометка: \(tool.rawValue)")
        }
        return true
    }

    private func updateRegionAccessibility(announce: Bool = true) {
        let value = "\(tool.rawValue). " + ScreenshotKeyboardRegion.description(keyboardRegion, in: bounds, flipped: true)
        ScreenshotRegionAccessibility.update(self, value: value, announce: announce)
    }
    @objc func undo(_ sender: Any?) { edits.undo(); onChange?() }
    @objc func redo(_ sender: Any?) { edits.redo(); onChange?() }
    func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        if item.action == #selector(undo(_:)) { return isEditingEnabled && !edits.annotations.isEmpty }
        if item.action == #selector(redo(_:)) { return isEditingEnabled && !edits.undone.isEmpty }
        return false
    }
    override func mouseDown(with event: NSEvent) {
        guard isEditingEnabled else { return }
        keyboardRegion = .zero
        updateRegionAccessibility(announce: false)
        textEntry?.commit()
        guard edits.annotations.count < ScreenshotEdits.maximumAnnotations else { onLimit?(); return }
        window?.makeFirstResponder(self)
        let point = location(event)
        if tool == .text { beginTextEntry(at: point); return }
        draft = ScreenshotAnnotation(tool: tool, points: [point], color: annotationColor)
    }
    override func mouseDragged(with event: NSEvent) {
        guard isEditingEnabled, var draft else { return }
        let point = location(event)
        if tool == .pen && !event.modifierFlags.contains(.shift) {
            if draft.points.count < 4096 { draft.points.append(point) }
        } else { draft.points = [draft.points[0], point] }
        self.draft = draft
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard isEditingEnabled, draft != nil else { return }
        mouseDragged(with: event)
        if let draft { edits.append(draft) }
        draft = nil
        onChange?()
    }
    private func location(_ event: NSEvent) -> CGPoint {
        let p = convert(event.locationInWindow, from: nil)
        return CGPoint(x: min(bounds.width, max(0, p.x)), y: min(bounds.height, max(0, p.y)))
    }

    func beginTextEntry(at point: CGPoint) {
        textEntry?.cancel()
        textEntry?.removeFromSuperview()
        let markupColor = annotationColor
        let frame = ScreenshotTextLayout.entryFrame(at: point, in: bounds)
        let field = ScreenshotInlineTextField(frame: frame)
        field.placeholderString = "Введите текст"
        field.font = NSFont(name: ScreenshotTextLayout.fontName, size: ScreenshotTextLayout.fontSize)
        field.textColor = NSColor(cgColor: markupColor.cgColor)
        field.backgroundColor = .windowBackgroundColor
        field.drawsBackground = true
        field.isBordered = false
        field.lineBreakMode = .byTruncatingTail
        field.focusRingType = .default
        field.setAccessibilityLabel("Текст пометки")
        field.onCommit = { [weak self, weak field] value in
            guard let self, let field else { return }
            let text = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1000))
            field.removeFromSuperview()
            self.textEntry = nil
            if !text.isEmpty { self.onTextCommitted?(frame.origin, text, markupColor) }
            self.window?.makeFirstResponder(self)
        }
        field.onCancel = { [weak self, weak field] in
            field?.removeFromSuperview()
            self?.textEntry = nil
            self?.window?.makeFirstResponder(self)
        }
        addSubview(field)
        textEntry = field
        window?.makeFirstResponder(field)
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: 1, y: -1)
        ScreenshotRenderer.draw(image, annotations: edits.annotations + (draft.map { [$0] } ?? []), in: context)
        context.restoreGState()
        if !keyboardRegion.isEmpty {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let outline = NSBezierPath(rect: keyboardRegion)
            outline.lineWidth = 2
            outline.setLineDash([5, 3], count: 2, phase: 0)
            outline.stroke()
        }
    }
}
