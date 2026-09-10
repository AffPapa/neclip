import AppKit
import ScreenCaptureKit

extension Notification.Name {
    static let neClipScreenshotRequested = Notification.Name("org.affpapa.neclip.screenshotRequested")
}

/// Owns at most one capture/selection/editor. There is no launch-time screen access.
@MainActor
final class ScreenshotCoordinator {
    private var captureTask: Task<Void, Never>?
    private var selection: NSWindow?
    private var editor: ScreenshotEditorWindowController?
    private var screenObserver: NSObjectProtocol?
    private let monitor: ClipboardMonitor

    init(monitor: ClipboardMonitor) { self.monitor = monitor }

    func start() {
        if let editor { editor.showWindow(nil); editor.window?.makeKeyAndOrderFront(nil); return }
        if let selection { selection.makeKeyAndOrderFront(nil); return }
        guard captureTask == nil else { return }
        let sourceBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
        let frame = screen.frame
        let displayID = CGDirectDisplayID(number.uint32Value)
        // Asking only here keeps ordinary clipboard use free of Screen Recording prompts.
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            let alert = NSAlert()
            alert.messageText = "Разрешите создание скриншотов"
            alert.informativeText = "В настройках macOS разрешите NeClip запись экрана. Она используется только для снимка по вашей команде. Затем попробуйте снова."
            alert.addButton(withTitle: "Открыть настройки macOS")
            alert.addButton(withTitle: "Не сейчас")
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                NSWorkspace.shared.open(url)
            }
            return
        }
        captureTask = Task { [weak self] in
            guard let self else { return }
            defer { captureTask = nil }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                try Task.checkCancellation()
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    throw ScreenshotFailure.invalidImage
                }
                // Freeze before creating our overlay. Excluding all NeClip windows
                // would reveal covered content and prevent screenshots of Settings.
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let configuration = SCStreamConfiguration()
                configuration.width = Int((filter.contentRect.width * CGFloat(filter.pointPixelScale)).rounded())
                configuration.height = Int((filter.contentRect.height * CGFloat(filter.pointPixelScale)).rounded())
                guard configuration.width > 0, configuration.height > 0,
                      configuration.width <= ScreenshotRenderer.maximumPixels / configuration.height else {
                    throw ScreenshotFailure.displayTooLarge
                }
                configuration.showsCursor = false
                configuration.colorSpaceName = CGColorSpace.sRGB
                configuration.captureResolution = .best
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                try Task.checkCancellation()
                guard NSScreen.screens.contains(where: {
                    ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
                        && $0.frame == frame
                }) else { throw ScreenshotFailure.invalidImage }
                showSelection(image: image, frame: frame, sourceBundleID: sourceBundleID)
            } catch is CancellationError {
                // Cancellation neither writes files nor changes the clipboard.
            } catch {
                showError((error as? ScreenshotFailure)?.errorDescription
                    ?? "Не удалось сделать снимок. Проверьте разрешение записи экрана и повторите попытку.")
            }
        }
    }

    func cancel() {
        captureTask?.cancel()
        closeSelection()
    }

    func prepareForTermination() -> Bool {
        guard let editor, let window = editor.window else { return true }
        return editor.windowShouldClose(window)
    }

    private func showSelection(image: CGImage, frame: CGRect, sourceBundleID: String?) {
        let window = ScreenshotSelectionWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        let view = ScreenshotSelectionView(frame: CGRect(origin: .zero, size: frame.size), image: image)
        view.onCancel = { [weak self] in self?.closeSelection() }
        view.onSelect = { [weak self] rect in
            guard let self else { return }
            closeSelection()
            do {
                guard let pixels = ScreenshotRenderer.pixelRect(
                    selection: rect, screen: CGRect(origin: .zero, size: frame.size),
                    width: image.width, height: image.height) else { throw ScreenshotFailure.emptySelection }
                let cropped = try ScreenshotRenderer.crop(image, to: pixels)
                showEditor(image: cropped, sourceBundleID: sourceBundleID)
            } catch { showError("Не удалось выделить область. Попробуйте снова.") }
        }
        window.contentView = view
        selection = window
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeSelection() }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
    }

    private func closeSelection() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        selection?.close()
        selection = nil
    }

    func showEditor(image: CGImage, sourceBundleID: String?) {
        guard editor == nil else { return }
        // Synthetic QA must never overwrite the user's working clipboard.
        let pasteboard = RuntimeIdentity.isScreenshotQA
            ? NSPasteboard(name: .init("org.affpapa.neclip.screenshot-qa")) : .general
        let controller = ScreenshotEditorWindowController(image: image, pasteboard: pasteboard)
        controller.onCopy = { [weak self] data in
            guard let self else { return }
            let stored = monitor.recordScreenshot(data, width: image.width, height: image.height, sourceBundleID: sourceBundleID)
            LayoutFeedbackHUD.shared.show(stored ? "Скриншот скопирован" : "Скопировано без истории · действуют её ограничения")
        }
        controller.onClose = { [weak self] in self?.editor = nil }
        editor = controller
        NSApp.activate(ignoringOtherApps: true)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Скриншот не создан"
        alert.informativeText = message
        alert.runModal()
    }
}

@MainActor
private final class ScreenshotSelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class ScreenshotSelectionView: NSView {
    let image: NSImage
    var onCancel: (() -> Void)?
    var onSelect: ((CGRect) -> Void)?
    private var start: CGPoint?
    private var selection = CGRect.zero
    override var acceptsFirstResponder: Bool { true }

    init(frame: CGRect, image: CGImage) {
        self.image = NSImage(cgImage: image, size: frame.size)
        super.init(frame: frame)
        setAccessibilityLabel("Выделите область экрана мышью. Escape — отмена.")
    }
    required init?(coder: NSCoder) { nil }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() }
    }
    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start else { return }
        let end = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(start.x - end.x), height: abs(start.y - end.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        mouseDragged(with: event)
        if selection.width >= 2, selection.height >= 2 { onSelect?(selection) }
        else { start = nil }
    }
    override func draw(_ dirtyRect: NSRect) {
        image.draw(in: bounds)
        NSColor.black.withAlphaComponent(0.38).setFill()
        if selection.isEmpty { bounds.fill() }
        else {
            CGRect(x: 0, y: 0, width: bounds.width, height: selection.minY).fill()
            CGRect(x: 0, y: selection.maxY, width: bounds.width, height: bounds.height - selection.maxY).fill()
            CGRect(x: 0, y: selection.minY, width: selection.minX, height: selection.height).fill()
            CGRect(x: selection.maxX, y: selection.minY, width: bounds.width - selection.maxX, height: selection.height).fill()
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 1
            border.stroke()
        }
        let hint = "Выделите область · Esc — отмена"
        (hint as NSString).draw(at: CGPoint(x: 24, y: bounds.height - 44), withAttributes: [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium), .foregroundColor: NSColor.white
        ])
    }
}
