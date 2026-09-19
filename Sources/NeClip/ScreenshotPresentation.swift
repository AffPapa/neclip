import CoreGraphics

/// Presentation never resizes the source pixels or exposes unflattened marks.
enum ScreenshotPresentation: String, CaseIterable, Sendable {
    case original = "Без фона", light = "Светлый фон", dark = "Тёмный фон"

    func padding(width: Int, height: Int) -> Int {
        guard self != .original, width > 0, height > 0,
              width <= ScreenshotRenderer.maximumPixels,
              height <= ScreenshotRenderer.maximumPixels else { return 0 }
        for inset in stride(from: 24, through: 1, by: -1) {
            if width + 2 * inset <= ScreenshotRenderer.maximumPixels / (height + 2 * inset) { return inset }
        }
        return 0
    }

    func size(width: Int, height: Int) -> CGSize {
        let inset = padding(width: width, height: height)
        return CGSize(width: width + 2 * inset, height: height + 2 * inset)
    }

    func drawBackground(in context: CGContext, width: Int, height: Int) {
        let inset = padding(width: width, height: height)
        guard inset > 0 else { return }
        let size = size(width: width, height: height)
        context.saveGState()
        context.setFillColor(CGColor(gray: self == .dark ? 0.12 : 0.94, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))
        context.setShadow(offset: CGSize(width: 0, height: -2), blur: 8,
                          color: CGColor(gray: 0, alpha: 0.25))
        context.setFillColor(CGColor(gray: self == .dark ? 0.4 : 0.7, alpha: 1))
        context.fill(CGRect(x: inset, y: inset, width: width, height: height).insetBy(dx: -0.5, dy: -0.5))
        context.restoreGState()
    }
}
