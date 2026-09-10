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
    private var capturedImage: CGImage?
    private var captureGeneration: UInt = 0

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
        captureGeneration &+= 1
        let generation = captureGeneration
        // Put the lightweight selection shell on screen before the asynchronous
        // shareable-content query. The user gets immediate visual feedback;
        // drag remains disabled until the frozen frame arrives.
        showSelectionPlaceholder(frame: frame, sourceBundleID: sourceBundleID)
        // Asking only here keeps ordinary clipboard use free of Screen Recording prompts.
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            closeSelection()
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
                guard generation == captureGeneration else { return }
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    throw ScreenshotFailure.invalidImage
                }
                // The selection shell is already visible to make the shortcut feel
                // instant. Exclude only that shell from the frozen frame; excluding
                // every NeClip window would make it impossible to capture a window
                // the user intentionally selected.
                let overlayID = CGWindowID(selection?.windowNumber ?? 0)
                let excluded = content.windows.filter { $0.windowID == overlayID }
                let filter = SCContentFilter(display: display, excludingWindows: excluded)
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
                guard generation == captureGeneration else { return }
                guard NSScreen.screens.contains(where: {
                    ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
                        && $0.frame == frame
                }) else { throw ScreenshotFailure.invalidImage }
                capturedImage = image
                selection?.contentView.flatMap { $0 as? ScreenshotSelectionView }?.setImage(image)
            } catch is CancellationError {
                // Cancellation neither writes files nor changes the clipboard.
            } catch {
                closeSelection()
                showError((error as? ScreenshotFailure)?.errorDescription
                    ?? "Не удалось сделать снимок. Проверьте разрешение записи экрана и повторите попытку.")
            }
        }
    }

    func cancel() {
        captureGeneration &+= 1
        captureTask?.cancel()
        closeSelection()
    }

    func prepareForTermination() -> Bool {
        guard let editor, let window = editor.window else { return true }
        return editor.windowShouldClose(window)
    }

    private func showSelectionPlaceholder(frame: CGRect, sourceBundleID: String?) {
        closeSelection()
        capturedImage = nil
        let window = ScreenshotSelectionWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        let view = ScreenshotSelectionView(frame: CGRect(origin: .zero, size: frame.size), image: nil)
        view.onCancel = { [weak self] in self?.cancel() }
        view.onSelect = { [weak self] rect in
            guard let self, let image = capturedImage else { return }
            closeSelection()
            guard let pixels = ScreenshotRenderer.pixelRect(
                selection: rect, screen: CGRect(origin: .zero, size: frame.size),
                width: image.width, height: image.height) else {
                showError("Не удалось выделить область. Попробуйте снова.")
                return
            }
            // Cropping a Retina display can allocate tens of megabytes. Keep the
            // main actor free so the editor opens without a visible hitch.
            Task { [weak self] in
                do {
                    let cropped = try await Task.detached(priority: .userInitiated) {
                        try ScreenshotRenderer.crop(image, to: pixels)
                    }.value
                    self?.showEditor(image: cropped, sourceBundleID: sourceBundleID)
                } catch {
                    self?.showError("Не удалось выделить область. Попробуйте снова.")
                }
            }
        }
        window.contentView = view
        selection = window
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.cancel() } }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
    }

    private func closeSelection() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        selection?.close()
        selection = nil
        capturedImage = nil
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
    private(set) var image: NSImage?
    var onCancel: (() -> Void)?
    var onSelect: ((CGRect) -> Void)?
    private var start: CGPoint?
    private var selection = CGRect.zero
    private var pointer = CGPoint.zero
    private var pointerInside = false
    private var hasDragged = false
    private var trackingArea: NSTrackingArea?
    override var acceptsFirstResponder: Bool { true }

    init(frame: CGRect, image: CGImage?) {
        self.image = image.map { NSImage(cgImage: $0, size: frame.size) }
        super.init(frame: frame)
        setAccessibilityLabel("Нажмите и проведите мышью, чтобы выделить область экрана. Escape — отмена.")
    }
    required init?(coder: NSCoder) { nil }
    func setImage(_ image: CGImage) {
        self.image = NSImage(cgImage: image, size: bounds.size)
        start = nil
        selection = .zero
        hasDragged = false
        needsDisplay = true
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }
    override func updateTrackingAreas() {
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.activeAlways, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) {
        pointerInside = true
        pointer = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    override func mouseMoved(with event: NSEvent) {
        pointerInside = true
        pointer = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) {
        pointerInside = false
        needsDisplay = true
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onCancel?() }
    }
    override func mouseDown(with event: NSEvent) {
        guard image != nil else { return }
        start = convert(event.locationInWindow, from: nil)
        pointer = start ?? .zero
        hasDragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard image != nil, let start else { return }
        let end = convert(event.locationInWindow, from: nil)
        pointer = end
        hasDragged = true
        selection = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(start.x - end.x), height: abs(start.y - end.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard image != nil else { return }
        mouseDragged(with: event)
        if selection.width >= 2, selection.height >= 2 { onSelect?(selection) }
        else { start = nil; hasDragged = false }
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let image else {
            NSColor.black.withAlphaComponent(0.55).setFill()
            bounds.fill()
            drawInstruction(title: "Подготовка снимка…")
            return
        }
        image.draw(in: bounds)
        NSColor.black.withAlphaComponent(0.38).setFill()
        if selection.isEmpty {
            bounds.fill()
            if pointerInside && !hasDragged { drawCrosshair() }
            if !hasDragged {
                drawInstruction(title: "Проведите мышью, чтобы выделить область",
                                subtitle: "Esc — отмена")
            }
        } else {
            CGRect(x: 0, y: 0, width: bounds.width, height: selection.minY).fill()
            CGRect(x: 0, y: selection.maxY, width: bounds.width, height: bounds.height - selection.maxY).fill()
            CGRect(x: 0, y: selection.minY, width: selection.minX, height: selection.height).fill()
            CGRect(x: selection.maxX, y: selection.minY, width: bounds.width - selection.maxX, height: selection.height).fill()
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 1
            border.stroke()
        }
    }

    private func drawInstruction(title: String, subtitle: String? = nil) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.82)
        ]
        let titleSize = (title as NSString).size(withAttributes: titleAttributes)
        let subtitleSize = subtitle.map { ($0 as NSString).size(withAttributes: subtitleAttributes) } ?? .zero
        let width = max(titleSize.width, subtitleSize.width) + 40
        let height = subtitle == nil ? titleSize.height + 28 : titleSize.height + subtitleSize.height + 36
        let rect = CGRect(x: (bounds.width - width) / 2, y: (bounds.height - height) / 2,
                          width: width, height: height)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
        (title as NSString).draw(at: CGPoint(x: rect.minX + 20, y: rect.maxY - titleSize.height - 12),
                                 withAttributes: titleAttributes)
        if let subtitle {
            (subtitle as NSString).draw(at: CGPoint(x: rect.minX + 20, y: rect.minY + 12),
                                        withAttributes: subtitleAttributes)
        }
    }

    private func drawCrosshair() {
        NSColor.white.withAlphaComponent(0.72).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: CGPoint(x: pointer.x - 18, y: pointer.y))
        path.line(to: CGPoint(x: pointer.x + 18, y: pointer.y))
        path.move(to: CGPoint(x: pointer.x, y: pointer.y - 18))
        path.line(to: CGPoint(x: pointer.x, y: pointer.y + 18))
        path.stroke()
    }
}
