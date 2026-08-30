import AppKit
import SwiftUI

@MainActor
final class SnippetsEditorWindowController {
    static let shared = SnippetsEditorWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SnippetsEditorView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "NeClip — Сниппеты"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 760, height: 500))
            window.minSize = NSSize(width: 640, height: 420)
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SnippetsEditorView: View {
    @State private var snippets: [Snippet] = []
    @State private var selectedSnippetID: Int64?
    @State private var query = ""
    @State private var editorTitle = ""
    @State private var editorKeyword = ""
    @State private var editorContent = ""
    @State private var editorPinned = false
    @State private var errorMessage: String?
    @State private var isLoadingEditor = false
    @State private var pendingSave: DispatchWorkItem?
    @State private var deleteConfirmation = false

    var body: some View {
        HSplitView {
            VStack(spacing: 10) {
                TextField("Поиск сниппетов", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: query) { _, _ in reload() }

                List(snippets, id: \.id, selection: $selectedSnippetID) { snippet in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            if snippet.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.tint)
                            }
                            Text(snippet.title.isEmpty ? "Без названия" : snippet.title)
                                .lineLimit(1)
                        }
                        if let keyword = snippet.keyword, !keyword.isEmpty {
                            Text(keyword)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(snippet.id)
                }

                HStack {
                    Button(action: createSnippet) {
                        Label("Новый", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        deleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(selectedSnippetID == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
            }
            .padding(12)
            .frame(minWidth: 220, idealWidth: 250, maxWidth: 300)

            Group {
                if selectedSnippetID != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            TextField("Название", text: $editorTitle)
                                .textFieldStyle(.roundedBorder)
                            Toggle("Закрепить", isOn: $editorPinned)
                                .toggleStyle(.checkbox)
                                .fixedSize()
                        }

                        TextField("Ключ поиска, например ;thanks", text: $editorKeyword)
                            .textFieldStyle(.roundedBorder)

                        TextEditor(text: $editorContent)
                            .font(.system(.body, design: .monospaced))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(.separator, lineWidth: 1)
                            }

                        HStack {
                            Text("Доступно: {date}, {time}, {clipboard}")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            } else {
                                Text("Сохраняется автоматически")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(14)
                } else {
                    ContentUnavailableView {
                        Label("Выберите или создайте сниппет", systemImage: "scissors")
                    } description: {
                        Text("Папку заранее создавать не нужно.")
                    } actions: {
                        Button("Создать сниппет", action: createSnippet)
                    }
                }
            }
            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { reload() }
        .onChange(of: selectedSnippetID) { _, _ in loadEditor() }
        .onChange(of: editorTitle) { _, _ in scheduleSave() }
        .onChange(of: editorKeyword) { _, _ in scheduleSave() }
        .onChange(of: editorContent) { _, _ in scheduleSave() }
        .onChange(of: editorPinned) { _, _ in scheduleSave() }
        .alert("Удалить сниппет?", isPresented: $deleteConfirmation) {
            Button("Удалить", role: .destructive, action: deleteSelected)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private func reload(selecting id: Int64? = nil) {
        do {
            snippets = try Storage.shared.allSnippets(
                search: query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : query,
                pinnedOnly: false
            )
            errorMessage = nil
            if let id {
                selectedSnippetID = id
            } else if let selectedSnippetID,
                      !snippets.contains(where: { $0.id == selectedSnippetID }) {
                self.selectedSnippetID = nil
            }
        } catch {
            snippets = []
            errorMessage = "Не удалось загрузить сниппеты"
        }
    }

    private func createSnippet() {
        do {
            let folders = try Storage.shared.snippetFolders()
            let folderID: Int64
            if let existingID = folders.first?.id {
                folderID = existingID
            } else if let newID = try Storage.shared.addFolder(title: "Быстрые ответы")?.id {
                folderID = newID
            } else {
                errorMessage = "Не удалось создать папку"
                return
            }

            guard let snippet = try Storage.shared.addSnippet(
                folderID: folderID,
                title: "Новый сниппет",
                content: "",
                keyword: nil
            ), let id = snippet.id else {
                errorMessage = "Не удалось создать сниппет"
                return
            }
            query = ""
            reload(selecting: id)
        } catch {
            errorMessage = "Не удалось создать сниппет"
        }
    }

    private func deleteSelected() {
        guard let id = selectedSnippetID else { return }
        do {
            try Storage.shared.deleteSnippet(id: id)
            selectedSnippetID = nil
            reload()
        } catch {
            errorMessage = "Не удалось удалить сниппет"
        }
    }

    private func loadEditor() {
        pendingSave?.cancel()
        isLoadingEditor = true
        defer { isLoadingEditor = false }
        guard let id = selectedSnippetID,
              let snippet = snippets.first(where: { $0.id == id }) else {
            editorTitle = ""
            editorKeyword = ""
            editorContent = ""
            editorPinned = false
            return
        }
        editorTitle = snippet.title
        editorKeyword = snippet.keyword ?? ""
        editorContent = snippet.content
        editorPinned = snippet.isPinned
    }

    private func scheduleSave() {
        guard !isLoadingEditor, selectedSnippetID != nil else { return }
        pendingSave?.cancel()
        let item = DispatchWorkItem { saveEditor() }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func saveEditor() {
        guard let id = selectedSnippetID,
              var snippet = snippets.first(where: { $0.id == id }) else { return }
        snippet.title = editorTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        snippet.keyword = normalizedKeyword(editorKeyword)
        snippet.content = editorContent
        snippet.isPinned = editorPinned
        do {
            try Storage.shared.update(snippet)
            if let index = snippets.firstIndex(where: { $0.id == id }) {
                snippets[index] = snippet
            }
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось сохранить"
        }
    }

    private func normalizedKeyword(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix(";") ? trimmed : ";\(trimmed)"
    }
}
