import CoreGraphics
import CoreText
import Foundation
import ImageIO
import os
import UniformTypeIdentifiers

/// Low-cost diagnostics for the latency gate. Stages never include pixels,
/// clipboard contents, file paths or application names.
enum ScreenshotMetrics {
    private static let logger = Logger(subsystem: "org.affpapa.neclip", category: "Screenshot")
    static func mark(_ stage: String) { logger.debug("stage=\(stage, privacy: .public)") }
}

enum ScreenshotTool: String, CaseIterable, Sendable {
    case redact = "Скрыть", pen = "Перо", arrow = "Стрелка", rectangle = "Рамка", text = "Текст"

    var symbolName: String {
        switch self {
        case .redact: "eye.slash"
        case .pen: "pencil"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .text: "textformat"
        }
    }
}

/// Coordinates are pixels, origin at the top left, independent of view zoom.
struct ScreenshotAnnotation: Equatable, Sendable {
    var tool: ScreenshotTool
    var points: [CGPoint]
    var text = ""

    var rect: CGRect {
        guard let first = points.first, let last = points.last else { return .zero }
        return CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                      width: abs(last.x - first.x), height: abs(last.y - first.y))
    }
}

struct ScreenshotEdits: Sendable {
    static let maximumAnnotations = 128
    private(set) var annotations: [ScreenshotAnnotation] = []
    private(set) var undone: [ScreenshotAnnotation] = []
    mutating func append(_ annotation: ScreenshotAnnotation) {
        guard annotations.count < Self.maximumAnnotations, !annotation.points.isEmpty else { return }
        annotations.append(annotation)
        undone.removeAll()
    }
    mutating func undo() { if let item = annotations.popLast() { undone.append(item) } }
    mutating func redo() { if let item = undone.popLast() { annotations.append(item) } }
}

enum ScreenshotFailure: LocalizedError {
    case invalidImage, overlayUnavailable, filterUnavailable, displayChanged, displayTooLarge, emptySelection, exportFailed, clipboardChanged, clipboardWriteFailed
    var errorDescription: String? {
        switch self {
        case .invalidImage: "Не удалось подготовить изображение. Выберите меньшую область."
        case .overlayUnavailable: "Не удалось начать снимок экрана. Повторите попытку."
        case .filterUnavailable: "Не удалось подготовить область снимка. Повторите попытку."
        case .displayChanged: "Экран изменился во время снимка. Повторите попытку."
        case .displayTooLarge: "Разрешение экрана превышает лимит 32 мегапикселя. Снимки с этого экрана пока недоступны."
        case .emptySelection: "Выделите область экрана."
        case .exportFailed: "Не удалось сохранить снимок. Проверьте папку и свободное место."
        case .clipboardChanged: "Буфер уже изменился. Нажмите «Копировать» ещё раз, если хотите заменить его снимком."
        case .clipboardWriteFailed: "Не удалось записать снимок в буфер. Попробуйте ещё раз."
        }
    }
}

enum ScreenshotFormat: String, CaseIterable, Sendable {
    case png = "PNG", jpeg = "JPEG"
    var type: UTType { self == .png ? .png : .jpeg }
    var suffix: String { self == .png ? "png" : "jpg" }
}

enum ScreenshotFileExport {
    /// Called only after NSSavePanel confirms a destination/replacement.
    /// The input is the flattened export, never the source screenshot.
    static func write(_ data: Data, to url: URL) throws {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        try data.write(to: url, options: .atomic)
    }
}

enum ScreenshotHistoryPolicy {
    static func shouldStore(running: Bool, ignored: Bool, paused: Bool, capturesImages: Bool,
                            clipboardAllowed: Bool, sourceBundleID: String?, excludedApps: Set<String>,
                            excludedTransition: Bool, byteCount: Int, width: Int, height: Int) -> Bool {
        running && !ignored && !paused && capturesImages && clipboardAllowed
            && !ClipboardCapturePolicy.shouldRejectSource(bundleID: sourceBundleID,
                excludedTransitionActive: excludedTransition, excludedApps: excludedApps)
            && ClipboardCapturePolicy.acceptsImage(byteCount: byteCount, width: width, height: height)
    }
}

enum ScreenshotRenderer {
    // One 8-bit RGBA working image is at most 128 MB. No unbounded full-screen caches.
    static let maximumPixels = 32_000_000

    /// Magnification that fits an image's pixel canvas into a point-sized
    /// scroll viewport. AppKit applies the window backing scale after the
    /// scroll magnification; including it here prevents Retina canvases from
    /// being displayed at 2x and clipped at the bottom/right edges.
    static func fittingMagnification(contentSize: CGSize, imageSize: CGSize,
                                     backingScale: CGFloat, maximum: CGFloat) -> CGFloat {
        guard contentSize.width > 0, contentSize.height > 0,
              imageSize.width > 0, imageSize.height > 0,
              backingScale.isFinite, backingScale > 0,
              maximum.isFinite, maximum > 0 else { return 0 }
        let scale = max(1, backingScale)
        return min(maximum,
                   contentSize.width / (imageSize.width * scale),
                   contentSize.height / (imageSize.height * scale))
    }

    /// Returns a native-size capture when it fits the working-image budget and
    /// an aspect-preserving preview size otherwise. Large Retina displays can
    /// exceed the budget before the user has selected a small area; refusing
    /// the whole display makes the area tool appear broken. The selected crop
    /// remains bounded by the same limit and maps through the returned image
    /// dimensions, so no coordinate mismatch is introduced.
    /// ScreenCaptureKit's `contentRect` and `pointPixelScale` are the only
    /// geometry that is guaranteed to describe the source being captured.
    /// CGDisplayPixelsWide/High can describe the panel's mode rather than the
    /// scaled source exposed by ScreenCaptureKit, causing an implicit stretch.
    static func capturePixelSize(contentRect: CGRect, pointPixelScale: CGFloat) -> (width: Int, height: Int)? {
        guard contentRect.width.isFinite, contentRect.height.isFinite,
              pointPixelScale.isFinite, contentRect.width > 0,
              contentRect.height > 0, pointPixelScale > 0 else { return nil }
        let nativeWidth = Double(contentRect.width) * Double(pointPixelScale)
        let nativeHeight = Double(contentRect.height) * Double(pointPixelScale)
        guard nativeWidth.isFinite, nativeHeight.isFinite,
              nativeWidth >= 1, nativeHeight >= 1 else { return nil }
        return boundedPixelSize(width: Int(max(1, nativeWidth.rounded())), height: Int(max(1, nativeHeight.rounded())))
    }

    private static func boundedPixelSize(width: Int, height: Int) -> (width: Int, height: Int)? {
        guard width > 0, height > 0 else { return nil }
        let area = Double(width) * Double(height)
        guard area.isFinite else { return nil }
        let factor = min(1, sqrt(Double(maximumPixels) / area))
        let boundedWidth = Int(max(1, floor(Double(width) * factor)))
        let boundedHeight = Int(max(1, floor(Double(height) * factor)))
        guard boundedWidth <= maximumPixels / boundedHeight else { return nil }
        return (boundedWidth, boundedHeight)
    }

    static func pixelRect(selection: CGRect, screen: CGRect, width: Int, height: Int) -> CGRect? {
        pixelRect(selection: selection, screen: screen, sourceRect: screen, width: width, height: height)
    }

    /// Maps a selection made in the overlay's screen coordinate space into
    /// the source coordinate space reported by ScreenCaptureKit. The two
    /// spaces normally match, but can differ on scaled displays, menu-bar
    /// exclusions, and mixed-resolution monitor layouts.
    static func pixelRect(selection: CGRect, screen: CGRect, sourceRect: CGRect,
                         width: Int, height: Int) -> CGRect? {
        guard screen.width > 0, screen.height > 0, width > 0, height > 0,
              [selection.minX, selection.minY, selection.width, selection.height,
               screen.minX, screen.minY, screen.width, screen.height,
               sourceRect.minX, sourceRect.minY, sourceRect.width, sourceRect.height].allSatisfy(\.isFinite),
              sourceRect.width > 0, sourceRect.height > 0 else { return nil }
        let region = selection.intersection(screen)
        guard !region.isNull, region.width > 0, region.height > 0 else { return nil }
        let sourceRegion = CGRect(
            x: sourceRect.minX + (region.minX - screen.minX) / screen.width * sourceRect.width,
            y: sourceRect.minY + (region.minY - screen.minY) / screen.height * sourceRect.height,
            width: region.width / screen.width * sourceRect.width,
            height: region.height / screen.height * sourceRect.height
        )
        let sx = CGFloat(width) / sourceRect.width, sy = CGFloat(height) / sourceRect.height
        let left = floor((sourceRegion.minX - sourceRect.minX) * sx)
        let top = floor((sourceRect.maxY - sourceRegion.maxY) * sy)
        let right = ceil((sourceRegion.maxX - sourceRect.minX) * sx)
        let bottom = ceil((sourceRect.maxY - sourceRegion.minY) * sy)
        return CGRect(x: left, y: top, width: right - left, height: bottom - top)
            .intersection(CGRect(x: 0, y: 0, width: width, height: height))
    }

    static func context(width: Int, height: Int) throws -> CGContext {
        guard width > 0, height > 0, width <= maximumPixels / height,
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw ScreenshotFailure.invalidImage
        }
        return context
    }

    /// A real copy: releasing the full display image can release its backing buffer.
    static func crop(_ image: CGImage, to rect: CGRect) throws -> CGImage {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let rect = rect.integral.intersection(bounds)
        guard !rect.isNull, rect.width >= 1, rect.height >= 1 else {
            throw ScreenshotFailure.emptySelection
        }
        // Draw directly into the detached target. This avoids retaining a
        // source-backed cropped image while allocating the independent copy.
        let context = try context(width: Int(rect.width), height: Int(rect.height))
        context.draw(image, in: CGRect(x: -rect.minX, y: -rect.minY,
                                       width: CGFloat(image.width), height: CGFloat(image.height)))
        guard let result = context.makeImage() else { throw ScreenshotFailure.invalidImage }
        return result
    }

    static func render(_ image: CGImage, annotations: [ScreenshotAnnotation]) throws -> CGImage {
        let context = try context(width: image.width, height: image.height)
        draw(image, annotations: annotations, in: context)
        guard let result = context.makeImage() else { throw ScreenshotFailure.invalidImage }
        return result
    }

    /// Shared by preview and export. Redaction always wins, even over later annotations.
    static func draw(_ image: CGImage, annotations: [ScreenshotAnnotation], in context: CGContext) {
        context.saveGState()
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.clip(to: bounds)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.draw(image, in: bounds)
        context.translateBy(x: 0, y: CGFloat(image.height))
        context.scaleBy(x: 1, y: -1)
        context.setStrokeColor(CGColor(srgbRed: 0.95, green: 0.16, blue: 0.12, alpha: 1))
        context.setFillColor(CGColor(srgbRed: 0.95, green: 0.16, blue: 0.12, alpha: 1))
        context.setLineWidth(4)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        for annotation in annotations where annotation.tool != .redact {
            guard let start = annotation.points.first, let end = annotation.points.last else { continue }
            switch annotation.tool {
            case .pen:
                context.beginPath()
                context.move(to: start)
                for point in annotation.points.dropFirst() { context.addLine(to: point) }
                if annotation.points.count == 1 { context.addLine(to: CGPoint(x: start.x + 0.1, y: start.y)) }
                context.strokePath()
            case .arrow:
                context.beginPath()
                context.move(to: start)
                context.addLine(to: end)
                let angle = atan2(end.y - start.y, end.x - start.x)
                let size = min(18.0, hypot(end.x - start.x, end.y - start.y) * 0.4)
                for offset in [-CGFloat.pi / 6, CGFloat.pi / 6] {
                    context.move(to: end)
                    context.addLine(to: CGPoint(x: end.x - size * cos(angle + offset),
                                               y: end.y - size * sin(angle + offset)))
                }
                context.strokePath()
            case .rectangle: context.stroke(annotation.rect)
            case .text:
                context.saveGState()
                context.translateBy(x: start.x, y: start.y)
                context.scaleBy(x: 1, y: -1)
                context.textMatrix = .identity
                context.textPosition = CGPoint(x: 0, y: -24)
                let text = NSAttributedString(string: String(annotation.text.prefix(1000)), attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 24, nil),
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(srgbRed: 0.95, green: 0.16, blue: 0.12, alpha: 1)
                ])
                CTLineDraw(CTLineCreateWithAttributedString(text), context)
                context.restoreGState()
            case .redact: break
            }
        }
        context.setBlendMode(.copy)
        context.setShouldAntialias(false)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        for annotation in annotations where annotation.tool == .redact {
            context.fill(annotation.rect.integral)
        }
        context.restoreGState()
    }

    static func encode(_ image: CGImage, annotations: [ScreenshotAnnotation], format: ScreenshotFormat) throws -> Data {
        let flattened = try render(image, annotations: annotations)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.type.identifier as CFString, 1, nil) else {
            throw ScreenshotFailure.exportFailed
        }
        // Construct from pixels, never pass source metadata or hidden annotation layers.
        let properties: CFDictionary = (format == .jpeg
            ? [kCGImageDestinationLossyCompressionQuality: 0.9] : [:]) as CFDictionary
        CGImageDestinationAddImage(destination, flattened, properties)
        guard CGImageDestinationFinalize(destination) else { throw ScreenshotFailure.exportFailed }
        return data as Data
    }
}
