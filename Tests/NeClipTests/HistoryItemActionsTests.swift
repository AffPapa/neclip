import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import NeClip

@Suite(.serialized)
struct HistoryItemActionsTests {
    @Test func resolvesOnlyExplicitSafeOpenTargets() {
        let web = textItem("https://affpapa.org/neclip")
        #expect(HistoryItemActionResolver.openTarget(for: web)?.scheme == "https")
        #expect(HistoryItemActionResolver.openTarget(for: textItem("file:///tmp/private")) == nil)
        #expect(HistoryItemActionResolver.openTarget(for: textItem("https://example.com path")) == nil)

        let file = ClipItem(
            kind: .file,
            title: "report.txt",
            text: "/tmp/report.txt\n/tmp/other.txt",
            createdAt: Date()
        )
        #expect(
            HistoryItemActionResolver.openTarget(for: file, fileExists: { $0 == "/tmp/report.txt" })?.path
                == "/tmp/report.txt"
        )
        #expect(HistoryItemActionResolver.openTarget(for: file, fileExists: { _ in false }) == nil)
    }

    @Test func editsTextAndRenamesTransactionally() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let original = ClipItem(
            kind: .text,
            title: "Old",
            text: "old body",
            rtf: Data([1, 2, 3]),
            createdAt: Date()
        )
        let insertedID = try storage.insert(original)
        let id = try #require(insertedID)

        let updated = try storage.updateClip(id: id, title: "New title", text: "new body")
        #expect(updated.title == "New title")
        #expect(updated.text == "new body")
        #expect(updated.rtf == nil)
        #expect(updated.contentHash != nil)
        #expect(updated.contentBytes == Int64("new body".utf8.count))
    }

    @Test func rejectsEmptyEditedTextWithoutChangingStoredItem() throws {
        let storage = try Storage(inMemory: true, installStarterContent: false)
        let insertedID = try storage.insert(textItem("keep me"))
        let id = try #require(insertedID)

        #expect(throws: ClipStorageError.emptyText) {
            try storage.updateClip(id: id, title: "ignored", text: "   ")
        }
        let fetched = try storage.fetchClip(id: id)
        let stored = try #require(fetched)
        #expect(stored.title == "keep me")
        #expect(stored.text == "keep me")
    }

    @Test func imagePreviewIsDownsampledToTheInspectorBudget() throws {
        let width = 2_000
        let height = 1_000
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let original = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(
            original,
            UTType.png.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))

        let preview = try #require(HistoryImagePreview.pngData(from: original as Data))
        let source = try #require(CGImageSourceCreateWithData(preview as CFData, nil))
        let properties = try #require(
            CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        )
        let previewWidth = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let previewHeight = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(max(previewWidth, previewHeight) <= HistoryImagePreview.maximumPixelSize)
    }

    private func textItem(_ value: String) -> ClipItem {
        ClipItem(kind: .text, title: value, text: value, createdAt: Date())
    }
}
