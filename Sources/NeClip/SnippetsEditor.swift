import AppKit
import SwiftUI

@MainActor
final class SnippetsEditorWindowController: NSObject, NSWindowDelegate {
    static let shared = SnippetsEditorWindowController()

    private let model = SnippetsEditorModel()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SnippetsEditorView(model: model))
            let window = NSWindow(contentViewController: hosting)
            window.title = "NeClip — Сниппеты"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 760, height: 500))
            window.minSize = NSSize(width: 640, height: 420)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard model.flushPendingSave() else {
            sender.makeKeyAndOrderFront(nil)
            return false
        }
        return true
    }

    func prepareForTermination() -> Bool {
        guard model.flushPendingSave() else {
            show()
            return false
        }
        return true
    }
}

@MainActor
final class SnippetsEditorModel: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case changed
        case saving
        case saved
        case failed(String)
    }

    private struct Draft {
        var snippet: Snippet
    }

    @Published var folders: [SnippetFolder] = []
    @Published var snippets: [Snippet] = []
    @Published var selectedSnippetID: Int64?
    @Published var activeFolderID: Int64?
    @Published var query = ""

    @Published var editorTitle = ""
    @Published var editorKeyword = ""
    @Published var editorContent = ""
    @Published var editorPinned = false
    @Published var editorFolderID: Int64?

    @Published var saveState: SaveState = .idle
    @Published var message: String?
    @Published var showDeleteSnippetAlert = false

    @Published var showFolderEditor = false
    @Published var showFolderDeleteAlert = false
    @Published var folderNameDraft = ""
    @Published var editingFolderID: Int64?
    @Published var folderPendingDeletion: SnippetFolder?

    private var editingSnippet: Snippet?
    private var pendingDraft: Draft?
    private var saveTask: Task<Void, Never>?
    private var isLoadingEditor = false
    private let storage: Storage

    init(storage: Storage = .shared) {
        self.storage = storage
    }

    var folderEditorTitle: String {
        editingFolderID == nil ? "Новая папка" : "Переименовать папку"
    }

    var folderDeletionMessage: String {
        guard let folder = folderPendingDeletion, let id = folder.id else { return "" }
        let count = snippets.filter { $0.folderID == id }.count
        if count == 0 {
            return "Папка «\(folder.title)» пуста. Это действие нельзя отменить."
        }
        return "\(count) \(snippetWord(for: count)) останутся и перейдут в раздел «Без папки»."
    }

    func reload(selecting id: Int64? = nil, reloadEditor: Bool = false) {
        do {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            folders = try storage.snippetFolders()
            snippets = try storage.allSnippets(
                search: trimmedQuery.isEmpty ? nil : trimmedQuery,
                pinnedOnly: false
            )
            message = nil
            if let id {
                selectedSnippetID = id
                loadEditor(id: id)
            } else if let selectedSnippetID,
                      snippets.contains(where: { $0.id == selectedSnippetID }) {
                if reloadEditor { loadEditor(id: selectedSnippetID) }
            } else if pendingDraft == nil, let firstID = firstVisibleSnippetID() {
                selectedSnippetID = firstID
                loadEditor(id: firstID)
            } else if pendingDraft == nil {
                selectedSnippetID = nil
                clearEditor()
            }
        } catch {
            folders = []
            snippets = []
            message = "Не удалось загрузить сниппеты"
        }
    }

    func selectSnippet(_ id: Int64?) {
        guard id != selectedSnippetID else { return }
        guard flushPendingSave() else { return }
        selectedSnippetID = id
        if let id {
            loadEditor(id: id)
        } else {
            clearEditor()
        }
    }

    func snippets(in folderID: Int64?) -> [Snippet] {
        snippets
            .filter { $0.folderID == folderID }
            .sorted {
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                return ($0.id ?? 0) < ($1.id ?? 0)
            }
    }

    /// Matches the visual order of the sidebar instead of the storage query's
    /// recency order, so the row highlighted on open is the row users see first.
    private func firstVisibleSnippetID() -> Int64? {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return snippets.first?.id
        }
        for folder in folders {
            if let folderID = folder.id, let id = snippets(in: folderID).first?.id {
                return id
            }
        }
        return snippets(in: nil).first?.id
    }

    func folderTitle(for folderID: Int64?) -> String {
        guard let folderID else { return "Без папки" }
        return folders.first(where: { $0.id == folderID })?.title ?? "Без папки"
    }

    func createSnippetInActiveFolder() {
        createSnippet(in: activeFolderID)
    }

    func createSnippet(in folderID: Int64?) {
        guard flushPendingSave() else { return }
        do {
            guard let snippet = try storage.addSnippet(
                folderID: folderID,
                title: "Новый сниппет",
                content: "",
                keyword: nil
            ), let id = snippet.id else {
                message = "Не удалось создать сниппет"
                return
            }
            activeFolderID = folderID
            query = ""
            reload(selecting: id)
        } catch {
            message = "Не удалось создать сниппет"
        }
    }

    func requestNewFolder() {
        guard flushPendingSave() else { return }
        editingFolderID = nil
        folderNameDraft = ""
        showFolderEditor = true
    }

    func requestRename(_ folder: SnippetFolder) {
        guard flushPendingSave() else { return }
        editingFolderID = folder.id
        folderNameDraft = folder.title
        showFolderEditor = true
    }

    func saveFolder() {
        let title = folderNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            message = "Введите название папки"
            return
        }
        do {
            if let editingFolderID {
                guard var folder = folders.first(where: { $0.id == editingFolderID }) else {
                    throw SnippetStorageError.folderNotFound
                }
                folder.title = title
                _ = try storage.update(folder)
                activeFolderID = editingFolderID
            } else {
                let folder = try storage.addFolder(title: title)
                activeFolderID = folder?.id
            }
            reload(reloadEditor: false)
        } catch {
            message = error.localizedDescription
        }
    }

    func requestDelete(_ folder: SnippetFolder) {
        guard flushPendingSave() else { return }
        folderPendingDeletion = folder
        showFolderDeleteAlert = true
    }

    func confirmDeleteFolder() {
        guard let folder = folderPendingDeletion, let id = folder.id else { return }
        do {
            try storage.deleteFolder(id: id)
            if activeFolderID == id { activeFolderID = nil }
            folderPendingDeletion = nil
            showFolderDeleteAlert = false
            reload(reloadEditor: true)
        } catch {
            message = "Не удалось удалить папку"
        }
    }

    func deleteSelected() {
        guard let id = selectedSnippetID else { return }
        saveTask?.cancel()
        saveTask = nil
        do {
            try storage.deleteSnippet(id: id)
            pendingDraft = nil
            selectedSnippetID = nil
            clearEditor()
            reload()
        } catch {
            if pendingDraft != nil {
                saveState = .failed("Не удалено · черновик сохранён для повтора")
            }
            message = "Не удалось удалить сниппет"
        }
    }

    func editorChanged() {
        guard !isLoadingEditor, var snippet = editingSnippet else { return }
        snippet.title = editorTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        snippet.keyword = normalizedKeyword(editorKeyword)
        snippet.content = editorContent
        snippet.isPinned = editorPinned
        snippet.folderID = editorFolderID
        guard snippet.title != editingSnippet?.title
                || snippet.keyword != editingSnippet?.keyword
                || snippet.content != editingSnippet?.content
                || snippet.isPinned != editingSnippet?.isPinned
                || snippet.folderID != editingSnippet?.folderID else {
            saveTask?.cancel()
            saveTask = nil
            pendingDraft = nil
            saveState = .saved
            message = nil
            return
        }
        message = nil
        pendingDraft = Draft(snippet: snippet)
        saveState = .changed
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.savePendingDraft()
        }
    }

    @discardableResult
    func flushPendingSave() -> Bool {
        saveTask?.cancel()
        saveTask = nil
        guard pendingDraft != nil else { return true }
        return savePendingDraft()
    }

    private func loadEditor(id: Int64) {
        guard let snippet = snippets.first(where: { $0.id == id }) else { return }
        isLoadingEditor = true
        editingSnippet = snippet
        activeFolderID = snippet.folderID
        editorTitle = snippet.title
        editorKeyword = snippet.keyword ?? ""
        editorContent = snippet.content
        editorPinned = snippet.isPinned
        editorFolderID = snippet.folderID
        pendingDraft = nil
        saveState = .saved
        isLoadingEditor = false
    }

    private func clearEditor() {
        isLoadingEditor = true
        editingSnippet = nil
        editorTitle = ""
        editorKeyword = ""
        editorContent = ""
        editorPinned = false
        editorFolderID = nil
        pendingDraft = nil
        saveState = .idle
        isLoadingEditor = false
    }

    @discardableResult
    private func savePendingDraft() -> Bool {
        guard let draft = pendingDraft else { return true }
        saveTask = nil
        saveState = .saving
        do {
            let saved = try storage.update(draft.snippet)
            if let index = snippets.firstIndex(where: { $0.id == saved.id }) {
                snippets[index] = saved
            }
            if editingSnippet?.id == saved.id {
                editingSnippet = saved
                activeFolderID = saved.folderID
            }
            pendingDraft = nil
            saveState = .saved
            message = nil
            return true
        } catch {
            pendingDraft = draft
            saveState = .failed("Не сохранено · повторить ⌘S")
            return false
        }
    }

    private func normalizedKeyword(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix(";") ? trimmed : ";\(trimmed)"
    }

    private func snippetWord(for count: Int) -> String {
        let mod100 = count % 100
        let mod10 = count % 10
        if (11...14).contains(mod100) { return "сниппетов" }
        if mod10 == 1 { return "сниппет" }
        if (2...4).contains(mod10) { return "сниппета" }
        return "сниппетов"
    }
}

private struct SnippetsEditorView: View {
    @ObservedObject var model: SnippetsEditorModel

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 240, idealWidth: 270, maxWidth: 310)

            editor
                .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { model.reload() }
        .onDisappear { model.flushPendingSave() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            model.flushPendingSave()
        }
        .onReceive(NotificationCenter.default.publisher(for: .neClipStorageDidChange)) { _ in
            model.reload()
        }
        .onChange(of: model.query) { _, _ in model.reload() }
        .onChange(of: model.editorTitle) { _, _ in model.editorChanged() }
        .onChange(of: model.editorKeyword) { _, _ in model.editorChanged() }
        .onChange(of: model.editorContent) { _, _ in model.editorChanged() }
        .onChange(of: model.editorPinned) { _, _ in model.editorChanged() }
        .onChange(of: model.editorFolderID) { _, _ in model.editorChanged() }
        .alert("Удалить сниппет?", isPresented: $model.showDeleteSnippetAlert) {
            Button("Удалить", role: .destructive, action: model.deleteSelected)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .alert(model.folderEditorTitle, isPresented: $model.showFolderEditor) {
            TextField("Название папки", text: $model.folderNameDraft)
            Button("Сохранить", action: model.saveFolder)
            Button("Отмена", role: .cancel) {}
        }
        .alert("Удалить папку?", isPresented: $model.showFolderDeleteAlert) {
            Button("Удалить папку", role: .destructive, action: model.confirmDeleteFolder)
            Button("Отмена", role: .cancel) { model.folderPendingDeletion = nil }
        } message: {
            Text(model.folderDeletionMessage)
        }
    }

    private var sidebar: some View {
        VStack(spacing: 10) {
            TextField("Поиск сниппетов", text: $model.query)
                .textFieldStyle(.roundedBorder)

            Text("Нажмите сниппет, чтобы изменить его справа")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            List(selection: Binding(
                get: { model.selectedSnippetID },
                set: { model.selectSnippet($0) }
            )) {
                if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ForEach(model.folders) { folder in
                        folderSection(folder)
                    }
                    unfiledSection
                } else {
                    searchResults
                }
            }
            .listStyle(.inset)

            HStack {
                Menu {
                    Button(
                        model.activeFolderID.map {
                            "Новый сниппет в «\(model.folderTitle(for: $0))»"
                        } ?? "Новый сниппет без папки",
                        action: model.createSnippetInActiveFolder
                    )
                    Button("Новая папка…", action: model.requestNewFolder)
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)

                Button(role: .destructive) {
                    model.showDeleteSnippetAlert = true
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(model.selectedSnippetID == nil)
                .accessibilityLabel("Удалить выбранный сниппет")
                Spacer()
            }
            .buttonStyle(.borderless)
            if let message = model.message, model.selectedSnippetID == nil {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private func folderSection(_ folder: SnippetFolder) -> some View {
        let items = folder.id.map { model.snippets(in: $0) } ?? []
        Section {
            if items.isEmpty {
                Text("Папка пуста")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { snippet in
                    snippetRow(snippet)
                        .tag(snippet.id)
                }
            }
        } header: {
            HStack(spacing: 6) {
                Button {
                    model.activeFolderID = folder.id
                } label: {
                    Label(folder.title, systemImage: "folder")
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Новые сниппеты будут добавляться в эту папку")
                Spacer()
                Text("\(items.count)")
                    .foregroundStyle(.secondary)
                Menu {
                    Button("Новый сниппет здесь") { model.createSnippet(in: folder.id) }
                    Button("Переименовать…") { model.requestRename(folder) }
                    Button("Удалить папку…", role: .destructive) { model.requestDelete(folder) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Действия с папкой \(folder.title)")
            }
        }
    }

    private var unfiledSection: some View {
        let items = model.snippets(in: nil)
        return Section {
            if items.isEmpty {
                Text("Сниппетов без папки нет")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { snippet in
                    snippetRow(snippet)
                        .tag(snippet.id)
                }
            }
        } header: {
            HStack {
                Button {
                    model.activeFolderID = nil
                } label: {
                    Label("Без папки", systemImage: "tray")
                }
                .buttonStyle(.plain)
                .accessibilityHint("Новые сниппеты будут добавляться без папки")
                Spacer()
                Text("\(items.count)")
                    .foregroundStyle(.secondary)
                Button {
                    model.createSnippet(in: nil)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Новый сниппет без папки")
            }
        }
    }

    private var searchResults: some View {
        Section("Результаты") {
            if model.snippets.isEmpty {
                Text("Ничего не найдено")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.snippets) { snippet in
                    snippetRow(snippet, folderSubtitle: model.folderTitle(for: snippet.folderID))
                        .tag(snippet.id)
                }
            }
        }
    }

    private func snippetRow(_ snippet: Snippet, folderSubtitle: String? = nil) -> some View {
        Button {
            model.selectSnippet(snippet.id)
        } label: {
            HStack(spacing: 8) {
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
                    HStack(spacing: 5) {
                        if let keyword = snippet.keyword, !keyword.isEmpty {
                            Text(keyword)
                                .font(.caption.monospaced())
                        }
                        if let folderSubtitle {
                            Text(folderSubtitle)
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: model.selectedSnippetID == snippet.id ? "pencil.circle.fill" : "pencil")
                    .foregroundStyle(model.selectedSnippetID == snippet.id ? Color.accentColor : Color.secondary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .help("Редактировать сниппет справа")
        .accessibilityLabel("Редактировать сниппет \(snippet.title.isEmpty ? "Без названия" : snippet.title)")
        .accessibilityHint("Открывает название, папку, ключ и текст справа")
        .listRowBackground(
            model.selectedSnippetID == snippet.id
                ? Color.accentColor.opacity(0.14)
                : Color.clear
        )
    }

    @ViewBuilder
    private var editor: some View {
        if model.selectedSnippetID != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Редактирование сниппета", systemImage: "pencil")
                        .font(.headline)
                    Spacer()
                    Text("Сохраняется автоматически")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                LabeledContent("Название") {
                    TextField("Название сниппета", text: $model.editorTitle)
                        .textFieldStyle(.roundedBorder)
                }

                LabeledContent("Папка") {
                    Picker("Папка", selection: $model.editorFolderID) {
                        Text("Без папки").tag(Optional<Int64>.none)
                        ForEach(model.folders) { folder in
                            if let id = folder.id {
                                Text(folder.title).tag(Optional(id))
                            }
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                LabeledContent("Ключ поиска") {
                    TextField("Например, ;thanks", text: $model.editorKeyword)
                        .textFieldStyle(.roundedBorder)
                }

                Toggle("Закрепить", isOn: $model.editorPinned)
                    .toggleStyle(.checkbox)

                Text("Текст")
                TextEditor(text: $model.editorContent)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("Текст сниппета")
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 1)
                    }

                HStack {
                    Text("Доступно: {date}, {time}, {clipboard}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let message = model.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                    } else {
                        saveStatus
                    }
                }
            }
            .padding(14)
        } else {
            ContentUnavailableView {
                Label("Сниппетов пока нет", systemImage: "scissors")
            } description: {
                Text("Создайте первый сниппет — поля редактирования сразу появятся здесь.")
            } actions: {
                Button("Создать сниппет без папки") { model.createSnippet(in: nil) }
                Button("Создать папку", action: model.requestNewFolder)
            }
        }
    }

    @ViewBuilder
    private var saveStatus: some View {
        switch model.saveState {
        case .idle:
            EmptyView()
        case .changed:
            Button {
                model.flushPendingSave()
            } label: {
                Label("Изменено", systemImage: "circle.fill")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("s", modifiers: .command)
            .foregroundStyle(.secondary)
        case .saving:
            Label("Сохранение…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        case .saved:
            Button {
                model.flushPendingSave()
            } label: {
                Label("Сохранено", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.plain)
            .keyboardShortcut("s", modifiers: .command)
            .foregroundStyle(.green)
        case .failed(let text):
            Button(text) { model.flushPendingSave() }
                .buttonStyle(.link)
                .keyboardShortcut("s", modifiers: .command)
                .foregroundStyle(.red)
        }
    }
}
