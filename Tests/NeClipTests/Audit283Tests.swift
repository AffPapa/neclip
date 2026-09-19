import AppKit
import GRDB
import ImageIO
import XCTest
@testable import NeClip

final class Audit283Tests: XCTestCase {
    @MainActor
    func testDeferredPasteRejectsChangedClipboardAndOnlyNewestRequestPosts() async throws {
        let board = NSPasteboard(name: .init("neclip-audit-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.clearContents()
        board.setString("first", forType: .string)
        let rejected = expectation(description: "stale paste rejected")
        let newest = expectation(description: "current paste posted")
        var posted = 0
        PasteService.completePaste(copyOnly: false, targetPID: 42, expectedGeneration: board.changeCount,
                                   pasteboard: board, currentPID: { 42 }, trusted: { true },
                                   postPaste: { _ in XCTFail("Stale paste posted"); return true }) {
            XCTAssertEqual($0, .failed(.clipboardChanged)); rejected.fulfill()
        }
        board.clearContents()
        board.setString("second", forType: .string)
        PasteService.completePaste(copyOnly: false, targetPID: 42, expectedGeneration: board.changeCount,
                                   pasteboard: board, currentPID: { 42 }, trusted: { true },
                                   postPaste: { _ in posted += 1; return true }) {
            XCTAssertEqual($0, .pasted); newest.fulfill()
        }
        await fulfillment(of: [rejected, newest], timeout: 2)
        XCTAssertEqual(posted, 1)
        XCTAssertEqual(board.string(forType: .string), "second")
    }

    @MainActor
    func testUnacknowledgedLayoutPasteNeverRestoresUnrelatedData() throws {
        let board = NSPasteboard(name: .init("neclip-audit-\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.clearContents()
        board.setString("replacement", forType: .string)
        let previous = NSPasteboardItem()
        previous.setString("PRIVATE_ORIGINAL_SENTINEL", forType: .string)
        var result: PasteResult?
        PasteService.confirmSelectionPaste(attemptsRemaining: 1, verifyReplacement: { false }, savedItems: [previous],
                                          replacementGeneration: board.changeCount, pasteboard: board) { result = $0 }
        XCTAssertEqual(result, .pasteUnconfirmed)
        // A delayed recipient now consumes this value, not the old secret.
        XCTAssertEqual(board.string(forType: .string), "replacement")
    }

    @MainActor
    func testRememberedFormatAndPopupKeepFilenameAndAllowedTypeConsistent() throws {
        _ = NSApplication.shared
        let image = try fixture()
        let controller = ScreenshotEditorWindowController(image: image)
        defer { controller.window?.close() }
        for format in ScreenshotFormat.allCases {
            let panel = controller.makeSavePanel(format: format)
            XCTAssertTrue(panel.nameFieldStringValue.hasSuffix("." + format.suffix))
            XCTAssertEqual(panel.allowedContentTypes, [format.type])
            let popup = try XCTUnwrap(panel.accessoryView as? NSPopUpButton)
            let other: ScreenshotFormat = format == .png ? .jpeg : .png
            popup.selectItem(withTitle: other.rawValue)
            XCTAssertTrue(NSApp.sendAction(try XCTUnwrap(popup.action), to: popup.target, from: popup))
            XCTAssertTrue(panel.nameFieldStringValue.hasSuffix("." + other.suffix))
            XCTAssertEqual(panel.allowedContentTypes, [other.type])
            let bytes = try ScreenshotRenderer.encode(image, annotations: [], format: other)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(bytes as CFData, nil))
            XCTAssertEqual(CGImageSourceGetType(source) as String?, other.type.identifier)
        }
    }

    @MainActor
    func testScreenshotControlsDoNotOverlapAtMinimumAndLargerWidths() throws {
        _ = NSApplication.shared
        let controller = ScreenshotEditorWindowController(image: try fixture())
        let window = try XCTUnwrap(controller.window), root = try XCTUnwrap(window.contentView)
        defer { window.close() }
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        for width in [660.0, 800.0, 1000.0] {
            window.setContentSize(CGSize(width: width, height: 450))
            root.layoutSubtreeIfNeeded()
            let controls = descendants(root).filter { $0 is NSButton || $0 is NSPopUpButton }
            XCTAssertEqual(controls.count, 12)
            for (index, control) in controls.enumerated() {
                let frame = control.convert(control.bounds, to: root)
                XCTAssertTrue(root.bounds.contains(frame), "\(control.accessibilityLabel() ?? "?") at \(width)")
                for other in controls.dropFirst(index + 1) {
                    XCTAssertFalse(frame.insetBy(dx: 1, dy: 1).intersects(other.convert(other.bounds, to: root)))
                }
            }
        }
    }

    @MainActor
    func testSmallScreenshotStaysCenteredInViewport() {
        let clip = ScreenshotClipView(frame: CGRect(x: 0, y: 0, width: 800, height: 500))
        clip.documentView = NSView(frame: CGRect(x: 0, y: 0, width: 64, height: 64))
        let result = clip.constrainBoundsRect(clip.bounds)
        XCTAssertEqual(result.midX, 32)
        XCTAssertEqual(result.midY, 32)
    }

    @MainActor
    func testTextCommitsAtVisibleAnchorIncludingTinyImages() throws {
        _ = NSApplication.shared
        let canvas = ScreenshotCanvas(image: try fixture())
        for point in [CGPoint.zero, CGPoint(x: 63, y: 63), CGPoint(x: 0, y: 63), CGPoint(x: 63, y: 0)] {
            var anchor: CGPoint?
            canvas.onTextCommitted = { point, _, _ in anchor = point }
            canvas.beginTextEntry(at: point)
            let field = try XCTUnwrap(canvas.subviews.first as? NSTextField)
            XCTAssertTrue(canvas.bounds.contains(field.frame))
            field.stringValue = "Label"
            let expected = field.frame.origin
            canvas.commitPendingText()
            XCTAssertEqual(anchor, expected)
        }
    }

    func testPresentationRetainsPixelsAndRedactionDoesNotLeak() throws {
        let first = try fixture(gray: 0.2), second = try fixture(gray: 0.8)
        let mask = ScreenshotAnnotation(tool: .redact, points: [.zero, CGPoint(x: 64, y: 64)])
        for style in ScreenshotPresentation.allCases {
            let image = try ScreenshotRenderer.render(first, annotations: [], presentation: style)
            let inset = style.padding(width: 64, height: 64)
            XCTAssertEqual(image.width, 64 + 2 * inset)
            XCTAssertEqual(image.height, 64 + 2 * inset)
            let inner = try ScreenshotRenderer.crop(image, to: CGRect(x: inset, y: inset, width: 64, height: 64))
            XCTAssertEqual(try ScreenshotRenderer.encode(inner, annotations: [], format: .png),
                           try ScreenshotRenderer.encode(first, annotations: [], format: .png))
            for format in ScreenshotFormat.allCases {
                XCTAssertEqual(try ScreenshotRenderer.encode(first, annotations: [mask], format: format, presentation: style),
                               try ScreenshotRenderer.encode(second, annotations: [mask], format: format, presentation: style))
            }
        }
        XCTAssertEqual(ScreenshotPresentation.light.padding(width: 8000, height: 4000), 0)
        XCTAssertNil(ScreenshotRenderer.capturePixelSize(contentRect: CGRect(x: 0, y: 0, width: 1e30, height: 100), pointPixelScale: 2))
    }

    func testCropUsesPreviewGeometryWithNegativeDisplayOrigin() throws {
        let rect = ScreenshotRenderer.pixelRect(selection: CGRect(x: -900, y: -300, width: 200, height: 100),
            screen: CGRect(x: -1000, y: -400, width: 1000, height: 800),
            sourceRect: CGRect(x: -1200, y: -500, width: 1200, height: 1000), width: 2400, height: 2000)
        XCTAssertEqual(rect, CGRect(x: 240, y: 250, width: 480, height: 250))
    }

    private func fixture(gray: CGFloat = 0.4) throws -> CGImage {
        let context = try ScreenshotRenderer.context(width: 64, height: 64)
        context.setFillColor(CGColor(gray: gray, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        return try XCTUnwrap(context.makeImage())
    }
}
