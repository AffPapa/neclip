import CoreGraphics
import ImageIO
import XCTest
@testable import NeClip

final class ScreenshotTests: XCTestCase {
    func testCapturePixelSizeKeepsNativeRetinaSizeWhenItFits() {
        XCTAssertEqual(
            ScreenshotRenderer.capturePixelSize(
                contentRect: CGRect(x: 0, y: 0, width: 1728, height: 1117),
                pointPixelScale: 2
            )?.width,
            3456
        )
        XCTAssertEqual(
            ScreenshotRenderer.capturePixelSize(
                contentRect: CGRect(x: 0, y: 0, width: 1728, height: 1117),
                pointPixelScale: 2
            )?.height,
            2234
        )
    }

    func testCapturePixelSizeDownscalesLargeRetinaDisplayWithoutExceedingBudget() {
        let size = ScreenshotRenderer.capturePixelSize(
            contentRect: CGRect(x: 0, y: 0, width: 7680, height: 4320),
            pointPixelScale: 1
        )
        guard let pixels = size else { return XCTFail("A valid large-display preview size is expected") }
        XCTAssertLessThanOrEqual(pixels.width * pixels.height, ScreenshotRenderer.maximumPixels)
        XCTAssertLessThan(pixels.width, 7680)
        XCTAssertLessThan(pixels.height, 4320)
        XCTAssertEqual(Double(pixels.width) / Double(pixels.height), 7680.0 / 4320.0, accuracy: 0.001)
    }

    func testCaptureUsesScreenCaptureKitLogicalGeometryAndScale() {
        let size = ScreenshotRenderer.capturePixelSize(
            contentRect: CGRect(x: 0, y: 0, width: 1512, height: 982),
            pointPixelScale: 2
        )
        XCTAssertEqual(size?.width, 3024)
        XCTAssertEqual(size?.height, 1964)
    }

    func testCapturePixelSizeRejectsInvalidInput() {
        XCTAssertNil(ScreenshotRenderer.capturePixelSize(contentRect: .zero, pointPixelScale: 2))
        XCTAssertNil(ScreenshotRenderer.capturePixelSize(
            contentRect: CGRect(x: 0, y: 0, width: 100, height: 100), pointPixelScale: 0
        ))
        XCTAssertNil(ScreenshotRenderer.capturePixelSize(
            contentRect: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 100), pointPixelScale: 2
        ))
    }

    func testFitMagnificationAccountsForRetinaBackingScale() {
        let fit = ScreenshotRenderer.fittingMagnification(
            contentSize: CGSize(width: 1000, height: 700),
            imageSize: CGSize(width: 2000, height: 1400),
            backingScale: 2,
            maximum: 4
        )
        XCTAssertEqual(fit, 0.5, accuracy: 0.001)
    }

    func testSaveWritesOnlyFlattenedPNGAndJPEGAndReplacesConfirmedTarget() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-export-test-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let image = try fixture(secret: 0.4)
        let mask = ScreenshotAnnotation(tool: .redact, points: [CGPoint(x: 5, y: 5), CGPoint(x: 20, y: 20)])
        for format in ScreenshotFormat.allCases {
            let url = folder.appendingPathComponent("confirmed-target.\(format.suffix)")
            try Data("old file".utf8).write(to: url)
            let data = try ScreenshotRenderer.encode(image, annotations: [mask], format: format)
            try ScreenshotFileExport.write(data, to: url)
            let saved = try Data(contentsOf: url)
            XCTAssertEqual(saved, data)
            let source = try XCTUnwrap(CGImageSourceCreateWithData(saved as CFData, nil))
            XCTAssertEqual(CGImageSourceGetType(source) as String?, format.type.identifier)
            XCTAssertEqual(CGImageSourceGetCount(source), 1)
        }
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: folder.path)),
                       ["confirmed-target.png", "confirmed-target.jpg"])
    }

    func testSaveFailurePreservesDirectoryAndDoesNotLeavePartialOutput() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("neclip-export-failure-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let destination = folder.appendingPathComponent("missing-parent/file.png")
        XCTAssertThrowsError(try ScreenshotFileExport.write(Data([1, 2, 3]), to: destination))
        XCTAssertThrowsError(try ScreenshotFileExport.write(Data([1, 2, 3]), to: folder))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [])
    }

    func testHistoryRespectsEveryPrivacyAndSizeGate() {
        func allowed(running: Bool = true, ignored: Bool = false, paused: Bool = false,
                     images: Bool = true, clipboard: Bool = true, source: String? = "org.test.editor",
                     transition: Bool = false, bytes: Int = 1024, width: Int = 32, height: Int = 32) -> Bool {
            ScreenshotHistoryPolicy.shouldStore(running: running, ignored: ignored, paused: paused,
                capturesImages: images, clipboardAllowed: clipboard, sourceBundleID: source,
                excludedApps: ["com.agilebits.onepassword7"], excludedTransition: transition,
                byteCount: bytes, width: width, height: height)
        }
        XCTAssertTrue(allowed())
        XCTAssertFalse(allowed(running: false))
        XCTAssertFalse(allowed(ignored: true))
        XCTAssertFalse(allowed(paused: true))
        XCTAssertFalse(allowed(images: false))
        XCTAssertFalse(allowed(clipboard: false))
        XCTAssertFalse(allowed(source: nil))
        XCTAssertFalse(allowed(source: "COM.AGILEBITS.ONEPASSWORD7"))
        XCTAssertFalse(allowed(transition: true))
        XCTAssertFalse(allowed(bytes: ClipboardCapturePolicy.maxEncodedImageBytes + 1))
        XCTAssertFalse(allowed(width: .max, height: .max))
    }

    @MainActor
    func testEditorHasFiveToolsAndNativeCopySaveUndoControls() throws {
        _ = NSApplication.shared
        let image = try fixture(secret: 0.3)
        let controller = ScreenshotEditorWindowController(image: image)
        let window = try XCTUnwrap(controller.window)
        let root = try XCTUnwrap(window.contentView)
        root.layoutSubtreeIfNeeded()
        func buttons(_ view: NSView) -> [NSButton] {
            (view as? NSButton).map { [$0] } ?? view.subviews.flatMap(buttons)
        }
        let all = buttons(root)
        // The image-first editor intentionally uses compact icon buttons. Verify
        // the stable accessibility labels instead of presentation titles.
        for tool in ScreenshotTool.allCases { XCTAssertEqual(all.filter { $0.accessibilityLabel() == tool.rawValue }.count, 1) }
        XCTAssertEqual(all.first { $0.accessibilityLabel() == "Копировать" }?.keyEquivalent, "\r")
        XCTAssertEqual(all.first { $0.accessibilityLabel() == "Сохранить" }?.keyEquivalent, "s")
        XCTAssertEqual(all.first { $0.accessibilityLabel() == "Отменить" }?.isEnabled, false)
        XCTAssertEqual(all.first { $0.accessibilityLabel() == "Повторить" }?.isEnabled, false)
        XCTAssertEqual(window.minSize, CGSize(width: 660, height: 380))
        XCTAssertTrue(controller.windowShouldClose(window))
        let zoom = try XCTUnwrap(all.compactMap { $0 as? NSPopUpButton }.first)
        func scrollView(_ view: NSView) -> NSScrollView? {
            (view as? NSScrollView) ?? view.subviews.compactMap(scrollView).first
        }
        let scroll = try XCTUnwrap(scrollView(root))
        zoom.selectItem(at: 1)
        NSApp.sendAction(try XCTUnwrap(zoom.action), to: zoom.target, from: zoom)
        XCTAssertEqual(scroll.magnification * window.backingScaleFactor, 1, accuracy: 0.01)
        zoom.selectItem(at: 2)
        NSApp.sendAction(try XCTUnwrap(zoom.action), to: zoom.target, from: zoom)
        XCTAssertEqual(scroll.magnification * window.backingScaleFactor, 2, accuracy: 0.01)
        if let folder = ProcessInfo.processInfo.environment["NECLIP_SCREENSHOT_TEST_OUTPUT"] {
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                window.appearance = NSAppearance(named: appearance)
                let bitmap = try XCTUnwrap(root.bitmapImageRepForCachingDisplay(in: root.bounds))
                root.cacheDisplay(in: root.bounds, to: bitmap)
                let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: URL(fileURLWithPath: folder).appendingPathComponent("editor-\(appearance.rawValue).png"))
            }
        }
        window.close()
    }
    func testCropCoordinatesOnRetinaAndNegativeOrigin() {
        let screen = CGRect(x: -1440, y: -100, width: 1440, height: 900)
        XCTAssertEqual(ScreenshotRenderer.pixelRect(
            selection: CGRect(x: -1400, y: 700, width: 100, height: 50),
            screen: screen, width: 2880, height: 1800),
            CGRect(x: 80, y: 100, width: 200, height: 100))
        XCTAssertEqual(ScreenshotRenderer.pixelRect(
            selection: CGRect(x: -1450, y: 780, width: 30, height: 40),
            screen: screen, width: 2880, height: 1800),
            CGRect(x: 0, y: 0, width: 40, height: 40))
        XCTAssertNil(ScreenshotRenderer.pixelRect(selection: .zero, screen: screen, width: 2880, height: 1800))
    }

    func testCropMapsOverlaySelectionIntoDifferentCaptureGeometry() {
        let result = ScreenshotRenderer.pixelRect(
            selection: CGRect(x: 100, y: 100, width: 200, height: 100),
            screen: CGRect(x: 0, y: 0, width: 1000, height: 800),
            sourceRect: CGRect(x: 0, y: 0, width: 1200, height: 1000),
            width: 2400, height: 2000
        )
        XCTAssertEqual(result, CGRect(x: 240, y: 1500, width: 480, height: 250))
    }

    @MainActor
    func testSelectionClampsDragAndEscapeCancelsWithoutPublishing() throws {
        let view = ScreenshotSelectionView(frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                           image: try fixture(secret: 0.2))
        var result: CGRect?
        var cancelled = false
        view.onSelect = { result = $0 }
        view.onCancel = { cancelled = true }
        func mouse(_ type: NSEvent.EventType, _ point: CGPoint) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
        }
        view.mouseDown(with: try mouse(.leftMouseDown, CGPoint(x: 90, y: 80)))
        view.mouseUp(with: try mouse(.leftMouseUp, CGPoint(x: -20, y: -10)))
        XCTAssertEqual(result, CGRect(x: 0, y: 0, width: 90, height: 80))
        result = nil
        view.mouseDown(with: try mouse(.leftMouseDown, CGPoint(x: 5, y: 5)))
        view.mouseUp(with: try mouse(.leftMouseUp, CGPoint(x: 5, y: 5)))
        XCTAssertNil(result)
        let escape = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 53))
        view.keyDown(with: escape)
        XCTAssertTrue(cancelled)
        XCTAssertNil(result)

        let pending = ScreenshotSelectionView(frame: CGRect(x: 0, y: 0, width: 100, height: 100), image: nil)
        var pendingResult: CGRect?
        pending.onSelect = { pendingResult = $0 }
        pending.mouseDown(with: try mouse(.leftMouseDown, CGPoint(x: 10, y: 10)))
        pending.mouseUp(with: try mouse(.leftMouseUp, CGPoint(x: 90, y: 90)))
        XCTAssertNil(pendingResult, "The selection shell must stay inert until the frame is ready")
    }

    func testPixelRoundingUsesIndependentScales() {
        XCTAssertEqual(ScreenshotRenderer.pixelRect(
            selection: CGRect(x: 0.2, y: 5.2, width: 1, height: 1),
            screen: CGRect(x: 0, y: 0, width: 10, height: 10), width: 20, height: 30),
            CGRect(x: 0, y: 11, width: 3, height: 4))
    }

    func testContextRejectsOversizedOrInvalidBuffers() {
        XCTAssertThrowsError(try ScreenshotRenderer.context(width: .max, height: .max))
        XCTAssertThrowsError(try ScreenshotRenderer.context(width: 0, height: 100))
        XCTAssertThrowsError(try ScreenshotRenderer.context(width: 10_000, height: 10_000))
    }

    func testUndoRedoAndNewBranch() {
        var edits = ScreenshotEdits()
        let a = ScreenshotAnnotation(tool: .rectangle, points: [.zero, CGPoint(x: 20, y: 30)])
        let b = ScreenshotAnnotation(tool: .arrow, points: [.zero, CGPoint(x: 30, y: 20)])
        edits.append(a)
        edits.append(b)
        edits.undo()
        XCTAssertEqual(edits.annotations, [a])
        edits.redo()
        XCTAssertEqual(edits.annotations, [a, b])
        edits.undo()
        edits.append(a)
        XCTAssertTrue(edits.undone.isEmpty)
        for _ in 0..<200 { edits.append(a) }
        XCTAssertEqual(edits.annotations.count, 128)
    }

    func testRedactedSecretsProduceIdenticalPNGAndJPEG() throws {
        let first = try fixture(secret: 0.1), second = try fixture(secret: 0.9)
        let annotations = [
            ScreenshotAnnotation(tool: .redact, points: [CGPoint(x: 5, y: 5), CGPoint(x: 20, y: 20)]),
            ScreenshotAnnotation(tool: .pen, points: [.zero, CGPoint(x: 30, y: 30)])
        ]
        for format in ScreenshotFormat.allCases {
            let a = try ScreenshotRenderer.encode(first, annotations: annotations, format: format)
            let b = try ScreenshotRenderer.encode(second, annotations: annotations, format: format)
            XCTAssertEqual(a, b, "Hidden pixels cannot affect the flattened output")
            let source = try XCTUnwrap(CGImageSourceCreateWithData(a as CFData, nil))
            XCTAssertEqual(CGImageSourceGetCount(source), 1)
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
            // ImageIO may generate structural color-space/dimension entries;
            // these are not source EXIF. No identifying metadata is permitted.
            let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:]
            XCTAssertTrue(Set(exif.keys).isSubset(of: ["ColorSpace", "PixelXDimension", "PixelYDimension"]))
            XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
            XCTAssertEqual(properties[kCGImagePropertyPixelWidth as String] as? Int, 32)
        }
    }

    @MainActor
    func testCopyRejectsInterveningClipboardWriteWithoutChangingIt() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("neclip.screenshot.test.\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        pasteboard.clearContents()
        pasteboard.setString("Before", forType: .string)
        let generation = pasteboard.changeCount
        pasteboard.clearContents()
        pasteboard.setString("New external copy", forType: .string)
        XCTAssertThrowsError(try ScreenshotClipboard.write(Data([1]), to: pasteboard, expectedChangeCount: generation))
        XCTAssertEqual(pasteboard.string(forType: .string), "New external copy")
        let png = try ScreenshotRenderer.encode(fixture(secret: 0.3), annotations: [], format: .png)
        try ScreenshotClipboard.write(png, to: pasteboard, expectedChangeCount: pasteboard.changeCount)
        XCTAssertEqual(pasteboard.data(forType: .png), png)
        XCTAssertNil(pasteboard.string(forType: .string))
        XCTAssertFalse((pasteboard.types ?? []).contains(.fileURL))
        // macOS can advertise converted TIFF automatically; NeClip itself
        // publishes only PNG and never a path to the original image.
    }

    func testFlatteningAndCropKeepTopLeftOrientation() throws {
        let image = try fixture(secret: 0.2)
        let crop = try ScreenshotRenderer.crop(image, to: CGRect(x: 5, y: 5, width: 15, height: 15))
        XCTAssertEqual(crop.width, 15)
        XCTAssertEqual(crop.height, 15)
        let rendered = try ScreenshotRenderer.render(image, annotations: [])
        XCTAssertEqual(pixel(rendered, x: 8, y: 8), pixel(image, x: 8, y: 8))
        XCTAssertNotEqual(pixel(rendered, x: 8, y: 8), pixel(rendered, x: 8, y: 28))
        XCTAssertEqual(pixel(crop, x: 3, y: 3), pixel(image, x: 8, y: 8))
        let hidden = try ScreenshotRenderer.render(image, annotations: [
            ScreenshotAnnotation(tool: .redact, points: [CGPoint(x: 5.2, y: 5.2), CGPoint(x: 19.8, y: 19.8)])
        ])
        XCTAssertEqual(pixel(hidden, x: 5, y: 5), [0, 0, 0])
        XCTAssertEqual(pixel(hidden, x: 19, y: 19), [0, 0, 0])
    }

    private func fixture(secret: CGFloat) throws -> CGImage {
        let context = try ScreenshotRenderer.context(width: 32, height: 32)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        context.setFillColor(CGColor(gray: secret, alpha: 1))
        context.fill(CGRect(x: 5, y: 12, width: 15, height: 15))
        return try XCTUnwrap(context.makeImage())
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> [UInt8] {
        let data = image.dataProvider!.data! as Data
        let offset = y * image.bytesPerRow + x * 4
        return Array(data[offset..<(offset + 3)])
    }
}
