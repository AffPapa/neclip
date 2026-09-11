import AppKit
import ScreenCaptureKit

extension Notification.Name {
    static let neClipScreenshotRequested = Notification.Name("org.affpapa.neclip.screenshotRequested")
    static let neClipFullScreenScreenshotRequested = Notification.Name("org.affpapa.neclip.fullScreenScreenshotRequested")
}

enum ScreenshotCaptureMode: Sendable {
    case area
    case fullScreen
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
    // ScreenCaptureKit's contentRect can differ from NSScreen.frame in
    // scaled/multi-display configurations. Keep the exact source geometry so
    // the user's selection is mapped proportionally into the captured raster.
    private var capturedSourceRect = CGRect.zero
    private var captureGeneration: UInt = 0
    private var cropTask: Task<Void, Never>?

    init(monitor: ClipboardMonitor) { self.monitor = monitor }

    func start() { start(mode: .area) }

    func startFullScreen() { start(mode: .fullScreen) }

    private func start(mode: ScreenshotCaptureMode) {
        ScreenshotMetrics.mark("hotkey")
        if let editor { editor.showWindow(nil); editor.window?.makeKeyAndOrderFront(nil); return }
        if let selection { selection.makeKeyAndOrderFront(nil); return }
        guard captureTask == nil else { return }
        cropTask?.cancel()
        cropTask = nil
        let sourceBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return }
        let frame = screen.frame
        let displayID = CGDirectDisplayID(number.uint32Value)
        captureGeneration &+= 1
        let generation = captureGeneration
        if mode == .area {
            // Put the lightweight selection shell on screen before the
            // asynchronous shareable-content query. The user gets immediate
            // visual feedback; drag remains disabled until the frozen frame
            // arrives.
            showSelectionPlaceholder(frame: frame, sourceBundleID: sourceBundleID)
        }
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
                ScreenshotMetrics.mark("content-ready")
                try Task.checkCancellation()
                guard generation == captureGeneration else { return }
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    throw ScreenshotFailure.overlayUnavailable
                }
                // The selection shell is already visible to make the shortcut feel
                // instant. Exclude only that shell from the frozen frame; excluding
                // every NeClip window would make it impossible to capture a window
                // the user intentionally selected.
                let overlayID = CGWindowID(selection?.windowNumber ?? 0)
                let filter: SCContentFilter
                if mode == .fullScreen {
                    // No NeClip overlay exists in this mode, so a plain
                    // display filter is both faster and more faithful.
                    filter = SCContentFilter(display: display, excludingWindows: [])
                } else if overlayID != 0,
                   let overlay = content.windows.first(where: { $0.windowID == overlayID }) {
                    filter = SCContentFilter(display: display, excludingWindows: [overlay])
                } else if let application = content.applications.first(where: {
                    $0.bundleIdentifier == Bundle.main.bundleIdentifier
                }) {
                    // WindowServer can omit a newly-created borderless window
                    // from `content.windows` for one frame. Excluding the
                    // owning application is the safe full-screen fallback: it
                    // removes the selection shell without hiding any other app.
                    // Never fall back to an unfiltered display.
                    filter = SCContentFilter(display: display,
                                              excludingApplications: [application],
                                              exceptingWindows: [])
                    ScreenshotMetrics.mark("filter-app-fallback")
                } else {
                    throw ScreenshotFailure.overlayUnavailable
                }
                guard let pixelSize = ScreenshotRenderer.capturePixelSize(
                    contentRect: filter.contentRect,
                    pointPixelScale: CGFloat(filter.pointPixelScale)
                ) else { throw ScreenshotFailure.filterUnavailable }
                let configuration = SCStreamConfiguration()
                configuration.width = pixelSize.width
                configuration.height = pixelSize.height
                // Make the source and destination explicit. Without this,
                // ScreenCaptureKit may place a display-sized source in the
                // configured canvas's top-left when dimensions differ on
                // Retina/scaled displays, leaving blank margins and breaking
                // the selection-to-image correspondence.
                configuration.sourceRect = filter.contentRect
                configuration.scalesToFit = true
                configuration.preservesAspectRatio = true
                configuration.showsCursor = false
                configuration.colorSpaceName = CGColorSpace.sRGB
                configuration.captureResolution = .best
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                ScreenshotMetrics.mark("capture-ready")
                try Task.checkCancellation()
                guard generation == captureGeneration else { return }
                guard image.width > 0, image.height > 0,
                      image.width <= ScreenshotRenderer.maximumPixels / image.height else {
                    throw ScreenshotFailure.displayTooLarge
                }
                guard NSScreen.screens.contains(where: {
                    ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
                        && $0.frame == frame
                }) else { throw ScreenshotFailure.displayChanged }
                if mode == .fullScreen {
                    showEditor(image: image, sourceBundleID: sourceBundleID)
                    return
                }
                guard selection != nil else { return }
                capturedImage = image
                capturedSourceRect = filter.contentRect
                selection?.contentView.flatMap { $0 as? ScreenshotSelectionView }?.setImage(image)
                ScreenshotMetrics.mark("selection-ready")
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
        cropTask?.cancel()
        cropTask = nil
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
            let sourceRect = self.capturedSourceRect
            closeSelection()
            guard let pixels = ScreenshotRenderer.pixelRect(
                selection: rect, screen: CGRect(origin: .zero, size: frame.size),
                sourceRect: sourceRect,
                width: image.width, height: image.height) else {
                showError("Не удалось выделить область. Попробуйте снова.")
                return
            }
            // Cropping a Retina display can allocate tens of megabytes. Keep the
            // main actor free so the editor opens without a visible hitch.
            let generation = captureGeneration
            cropTask = Task { [weak self] in
                defer { self?.cropTask = nil }
                do {
                    let cropped = try await Task.detached(priority: .userInitiated) {
                        try ScreenshotRenderer.crop(image, to: pixels)
                    }.value
                    guard let self, !Task.isCancelled, self.captureGeneration == generation else { return }
                    self.showEditor(image: cropped, sourceBundleID: sourceBundleID)
                } catch {
                    guard !Task.isCancelled else { return }
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
        capturedSourceRect = .zero
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
        ScreenshotMetrics.mark("editor-visible")
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
    private var spaceHeld = false
    private var movingSelection = false
    private var moveOrigin = CGPoint.zero
    private var selectionAtMoveStart = CGRect.zero
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
        switch event.keyCode {
        case 53: onCancel?()
        case 49: spaceHeld = true
        default: break
        }
    }
    override func keyUp(with event: NSEvent) {
        if event.keyCode == 49 { spaceHeld = false }
    }
    override func mouseDown(with event: NSEvent) {
        guard image != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        if spaceHeld, !selection.isEmpty, selection.contains(point) {
            movingSelection = true
            moveOrigin = point
            selectionAtMoveStart = selection
            return
        }
        start = point
        pointer = start ?? .zero
        hasDragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard image != nil else { return }
        let end = convert(event.locationInWindow, from: nil)
        pointer = end
        if movingSelection {
            let delta = CGPoint(x: end.x - moveOrigin.x, y: end.y - moveOrigin.y)
            var moved = selectionAtMoveStart.offsetBy(dx: delta.x, dy: delta.y)
            moved.origin.x = min(max(0, moved.origin.x), max(0, bounds.width - moved.width))
            moved.origin.y = min(max(0, moved.origin.y), max(0, bounds.height - moved.height))
            selection = moved
            needsDisplay = true
            return
        }
        guard let start else { return }
        hasDragged = true
        selection = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                           width: abs(start.x - end.x), height: abs(start.y - end.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        guard image != nil else { return }
        if movingSelection {
            movingSelection = false
            moveOrigin = .zero
            selectionAtMoveStart = .zero
            needsDisplay = true
            return
        }
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
            drawSelectionSize()
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

    private func drawSelectionSize() {
        let text = "\(Int(selection.width.rounded())) × \(Int(selection.height.rounded()))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attributes)
        let rect = CGRect(x: selection.minX, y: max(4, selection.minY - size.height - 10),
                          width: size.width + 14, height: size.height + 6)
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
        (text as NSString).draw(at: CGPoint(x: rect.minX + 7, y: rect.minY + 3), withAttributes: attributes)
    }
}
