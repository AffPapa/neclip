import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

enum HistoryImagePreview {
    static let maximumPixelSize = 1_600

    /// Produces a bounded preview off the main actor. The inspector never keeps
    /// or repeatedly decodes the original image BLOB while SwiftUI recomputes.
    static func pngData(from data: Data, maximumPixelSize: Int = maximumPixelSize) -> Data? {
        guard maximumPixelSize > 0,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                  kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, thumbnail, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}

enum HistoryItemActionResolver {
    static func openTarget(for item: ClipItem, fileExists: (String) -> Bool = {
        FileManager.default.fileExists(atPath: $0)
    }) -> URL? {
        switch item.kind {
        case .text:
            guard let value = item.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.contains(where: \.isWhitespace),
                  let url = URL(string: value),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  url.host != nil else { return nil }
            return url
        case .file:
            guard let firstPath = item.text?
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
                .first,
                fileExists(firstPath) else { return nil }
            return URL(fileURLWithPath: firstPath)
        case .image:
            return nil
        }
    }
}

@MainActor
final class HistoryItemInspectorWindowController: NSObject, NSWindowDelegate {
    static let shared = HistoryItemInspectorWindowController()
    private let session = HistoryItemInspectorSession()
    private var window: NSWindow?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(storageDidChange),
                                               name: .neClipStorageDidChange, object: Storage.shared)
    }

    func show(clipID: Int64) {
        if session.model?.id == clipID {
            session.invalidateRequests()
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            return
        }
        let request = session.beginRequest()
        Task { [weak self] in
            do {
                let payload = try await Task.detached {
                    let item = try Storage.shared.fetchClip(id: clipID)
                    let preview = item?.data.flatMap {
                        HistoryImagePreview.pngData(from: $0)
                    }
                    return (item, preview)
                }.value
                guard let self, self.session.isCurrent(request) else { return }
                guard let item = payload.0 else {
                    self.showError("Элемент истории уже удалён")
                    return
                }
                guard self.prepareToLeave(), self.session.isCurrent(request),
                      self.session.accept(item, imagePreviewData: payload.1, request: request) else { return }
                self.present()
            } catch {
                guard let self, self.session.isCurrent(request) else { return }
                self.showError("Не удалось открыть элемент")
            }
        }
    }

    private func present() {
        guard let model = session.model else { return }
        let hosting = NSHostingController(rootView: HistoryItemInspectorView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "\(RuntimeIdentity.displayName) — Просмотр"
        window.styleMask = [.titled, .closable, .resizable]
        window.minSize = NSSize(width: 500, height: 360)
        window.setContentSize(NSSize(width: 620, height: 500))
        window.isReleasedWhenClosed = false
        window.delegate = self
        RuntimeIdentity.configurePreviewWindow(window)
        window.center()
        self.window?.delegate = nil
        self.window?.close()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard prepareToLeave() else { return false }
        session.invalidate()
        return true
    }

    func prepareForTermination() -> Bool {
        guard prepareToLeave() else { return false }
        session.invalidateRequests()
        return true
    }

    private func prepareToLeave() -> Bool {
        session.prepareToLeave { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.window?.makeKeyAndOrderFront(nil)
            let alert = NSAlert()
            alert.messageText = "Сохранить изменения в элементе истории?"
            alert.informativeText = "Без сохранения изменения названия и текста будут потеряны."
            alert.addButton(withTitle: "Сохранить")
            alert.addButton(withTitle: "Не сохранять")
            alert.addButton(withTitle: "Отмена")
            switch alert.runModal() {
            case .alertFirstButtonReturn: return .save
            case .alertSecondButtonReturn: return .discard
            default: return .cancel
            }
        }
    }

    @objc private func storageDidChange(_ notification: Notification) {
        guard StorageChangeDomain.from(notification) == .all else { return }
        session.invalidate()
        window?.delegate = nil
        window?.close()
        window = nil
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

@MainActor
final class HistoryItemInspectorSession {
    enum Decision { case save, discard, cancel }
    private(set) var model: HistoryItemInspectorModel?
    private var generation: UInt64 = 0
    private let storage: Storage

    init(storage: Storage = .shared) { self.storage = storage }

    func beginRequest() -> UInt64 {
        invalidateRequests()
        return generation
    }

    func invalidateRequests() { generation &+= 1 }
    func isCurrent(_ request: UInt64) -> Bool { request == generation }

    @discardableResult
    func accept(_ item: ClipItem, imagePreviewData: Data? = nil, request: UInt64) -> Bool {
        guard isCurrent(request) else { return false }
        model = HistoryItemInspectorModel(item: item, imagePreviewData: imagePreviewData, storage: storage)
        return true
    }

    func prepareToLeave(decide: () -> Decision) -> Bool {
        guard let model, model.isDirty else { return true }
        switch decide() {
        case .save: return model.save()
        case .discard: return true
        case .cancel: return false
        }
    }

    /// Full erasure must drop drafts as well as rejecting every in-flight load.
    func invalidate() {
        invalidateRequests()
        model?.invalidate()
        model = nil
    }
}

@MainActor
final class HistoryItemInspectorModel: ObservableObject {
    let id: Int64
    let kind: ClipKind
    let appBundleID: String?
    let createdAt: Date
    @Published private(set) var contentBytes: Int64
    private(set) var imagePreview: NSImage?
    private(set) var ocrText: String?
    private let storage: Storage
    private var savedTitle: String
    private var savedText: String
    private var isValid = true

    @Published var title: String {
        didSet { if oldValue != title { feedback = nil } }
    }
    @Published var text: String {
        didSet { if oldValue != text { feedback = nil } }
    }
    @Published private(set) var feedback: String?

    init(item: ClipItem, imagePreviewData: Data?, storage: Storage = .shared) {
        self.storage = storage
        id = item.id ?? 0
        kind = item.kind
        appBundleID = item.appBundleID
        createdAt = item.createdAt
        contentBytes = item.contentBytes
        imagePreview = imagePreviewData.flatMap(NSImage.init(data:))
        ocrText = item.ocrText
        title = item.title
        text = item.text ?? ""
        savedTitle = item.title
        savedText = item.text ?? ""
    }

    var isDirty: Bool { isValid && (title != savedTitle || (kind == .text && text != savedText)) }

    var canOpen: Bool {
        isValid && HistoryItemActionResolver.openTarget(for: currentItem) != nil
    }

    @discardableResult
    func save() -> Bool {
        guard isValid else { return false }
        do {
            let updated = try storage.updateClip(
                id: id,
                title: title,
                text: kind == .text ? text : nil
            )
            title = updated.title
            text = updated.text ?? text
            savedTitle = title
            savedText = text
            contentBytes = updated.contentBytes
            feedback = "Сохранено"
            return true
        } catch {
            feedback = (error as? ClipStorageError)?.errorDescription
                ?? "Не удалось сохранить. Изменения оставлены в окне — попробуйте ещё раз."
            return false
        }
    }

    func invalidate() {
        isValid = false
        title = ""
        text = ""
        savedTitle = ""
        savedText = ""
        imagePreview = nil
        ocrText = nil
        contentBytes = 0
        feedback = nil
    }

    func open() {
        guard isValid, let url = HistoryItemActionResolver.openTarget(for: currentItem) else {
            feedback = "Открывать нечего"
            return
        }
        NSWorkspace.shared.open(url)
    }

    private var currentItem: ClipItem {
        ClipItem(
            id: id,
            kind: kind,
            title: title,
            text: text,
            data: nil,
            ocrText: ocrText,
            appBundleID: appBundleID,
            createdAt: createdAt,
            contentBytes: contentBytes
        )
    }
}

private struct HistoryItemInspectorView: View {
    @ObservedObject var model: HistoryItemInspectorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Название", text: $model.title)
                .textFieldStyle(.roundedBorder)

            Group {
                switch model.kind {
                case .text:
                    TextEditor(text: $model.text)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                case .file:
                    ScrollView {
                        Text(model.text)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                case .image:
                    if let image = model.imagePreview {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        ContentUnavailableView("Изображение недоступно", systemImage: "photo.badge.exclamationmark")
                    }
                }
            }
            .frame(minHeight: 220)

            if let ocr = model.ocrText, !ocr.isEmpty {
                DisclosureGroup("Распознанный текст") {
                    ScrollView {
                        Text(ocr)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 90)
                }
            }

            HStack(spacing: 12) {
                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let feedback = model.feedback {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if model.canOpen {
                    Button("Открыть", action: model.open)
                }
                Button("Сохранить") { model.save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!model.isDirty)
            }
        }
        .padding(16)
        .frame(minWidth: 500, minHeight: 360)
    }

    private var metadata: String {
        let kind: String = switch model.kind {
        case .text: "Текст"
        case .image: "Изображение"
        case .file: "Файл"
        }
        let bytes = ByteCountFormatter.string(fromByteCount: model.contentBytes, countStyle: .file)
        let app = AppMetadataStore.shared.metadata(for: model.appBundleID).name
        return "\(kind) · \(bytes) · \(app) · \(model.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
