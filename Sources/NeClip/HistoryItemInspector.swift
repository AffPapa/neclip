import AppKit
import SwiftUI

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
final class HistoryItemInspectorWindowController {
    static let shared = HistoryItemInspectorWindowController()
    private var window: NSWindow?

    func show(clipID: Int64) {
        Task { [weak self] in
            do {
                let item = try await Task.detached {
                    try Storage.shared.fetchClip(id: clipID)
                }.value
                guard let item else {
                    self?.showError("Элемент истории уже удалён")
                    return
                }
                self?.present(item)
            } catch {
                self?.showError("Не удалось открыть элемент")
            }
        }
    }

    private func present(_ item: ClipItem) {
        let model = HistoryItemInspectorModel(item: item)
        let hosting = NSHostingController(rootView: HistoryItemInspectorView(model: model))
        let window = NSWindow(contentViewController: hosting)
        window.title = "NeClip — Просмотр"
        window.styleMask = [.titled, .closable, .resizable]
        window.minSize = NSSize(width: 500, height: 360)
        window.setContentSize(NSSize(width: 620, height: 500))
        window.isReleasedWhenClosed = false
        window.center()
        self.window?.close()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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
private final class HistoryItemInspectorModel: ObservableObject {
    let id: Int64
    let kind: ClipKind
    let appBundleID: String?
    let createdAt: Date
    let contentBytes: Int64
    let imageData: Data?
    let ocrText: String?

    @Published var title: String
    @Published var text: String
    @Published var feedback: String?

    init(item: ClipItem) {
        id = item.id ?? 0
        kind = item.kind
        appBundleID = item.appBundleID
        createdAt = item.createdAt
        contentBytes = item.contentBytes
        imageData = item.data
        ocrText = item.ocrText
        title = item.title
        text = item.text ?? ""
    }

    var canOpen: Bool {
        HistoryItemActionResolver.openTarget(for: currentItem) != nil
    }

    func save() {
        do {
            let updated = try Storage.shared.updateClip(
                id: id,
                title: title,
                text: kind == .text ? text : nil
            )
            title = updated.title
            text = updated.text ?? text
            feedback = "Сохранено"
        } catch {
            feedback = error.localizedDescription
        }
    }

    func open() {
        guard let url = HistoryItemActionResolver.openTarget(for: currentItem) else {
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
            data: imageData,
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
                    if let data = model.imageData, let image = NSImage(data: data) {
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
                Button("Сохранить", action: model.save)
                    .keyboardShortcut(.defaultAction)
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
        let app = model.appBundleID ?? "неизвестное приложение"
        return "\(kind) · \(bytes) · \(app) · \(model.createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
