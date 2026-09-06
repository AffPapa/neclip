import AppKit
import SwiftUI

@MainActor
final class SnippetsEditorWindowController: NSObject, NSWindowDelegate {
    static let shared = SnippetsEditorWindowController()

    private let model = SnippetsEditorModel()
    private var window: NSWindow?

    func show(snippetID: Int64? = nil) {
        if window == nil {
            let hosting = NSHostingController(rootView: SnippetsEditorView(model: model))
            let window = NSWindow(contentViewController: hosting)
            window.title = "\(RuntimeIdentity.displayName) — Сниппеты"
            window.styleMask = [.titled, .closable, .resizable]
            window.setContentSize(NSSize(width: 760, height: 500))
            window.minSize = NSSize(width: 640, height: 420)
            window.isReleasedWhenClosed = false
            window.delegate = self
            RuntimeIdentity.configurePreviewWindow(window)
            window.center()
            self.window = window
        }
        if let snippetID { model.openSnippet(id: snippetID) }
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

    enum EmptyEditorState: Equatable {
        case emptyLibrary
        case chooseSnippet
        case noSearchResults
    }

    private struct Draft {
        var snippet: Snippet
    }

    @Published var folders: [SnippetFolder] = []
    @Published var snippets: [SnippetSummary] = []
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
    @Published var folderEditorError: String?
    @Published var editingFolderID: Int64?
    @Published var folderPendingDeletion: SnippetFolder?
    @Published private(set) var removedSnippet: RemovedSnippet?
    @Published private var folderPendingDeletionCount: Int?

    private var editingSnippet: Snippet?
    private var pendingDraft: Draft?
    private var saveTask: Task<Void, Never>?
    private var queryTask: Task<Void, Never>?
    private var snippetsByFolderID: [Int64: [SnippetSummary]] = [:]
    private var unfiledSnippets: [SnippetSummary] = []
    private var isLoadingEditor = false
    private let storage: Storage

    init(storage: Storage = .shared) {
        self.storage = storage
    }

    var folderEditorTitle: String {
        editingFolderID == nil ? "Новая папка" : "Переименовать папку"
    }

    var canSaveFolder: Bool {
        !folderNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var emptyEditorState: EmptyEditorState {
        if !snippets.isEmpty { return .chooseSnippet }
        return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? .emptyLibrary : .noSearchResults
    }

    var folderDeletionMessage: String {
        guard let folder = folderPendingDeletion, folder.id != nil else { return "" }
        guard let count = folderPendingDeletionCount else {
            return "Сниппеты останутся и перейдут в раздел «Без папки»."
        }
        if count == 0 {
            return "Папка «\(folder.title)» пуста. Это действие нельзя отменить."
        }
        return "\(count) \(snippetWord(for: count)) останутся и перейдут в раздел «Без папки»."
    }

    func reload(selecting id: Int64? = nil, reloadEditor: Bool = false) {
        do {
            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            folders = try storage.snippetFolders()
            snippets = try storage.snippetSummaries(
                search: trimmedQuery.isEmpty ? nil : trimmedQuery,
                pinnedOnly: false
            )
            rebuildSnippetIndex()
            message = nil
            if let id {
                selectedSnippetID = id
                loadEditor(id: id)
            } else if let selectedSnippetID,
                      snippets.contains(where: { $0.id == selectedSnippetID }) {
                if pendingDraft == nil {
                    if reloadEditor {
                        loadEditor(id: selectedSnippetID)
                    } else {
                        refreshCleanEditor(id: selectedSnippetID)
                    }
                }
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
            rebuildSnippetIndex()
            message = "Не удалось загрузить сниппеты"
        }
    }

    func scheduleQueryReload() {
        queryTask?.cancel()
        queryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(120))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.reload()
        }
    }

    func storageDidChange(_ domain: StorageChangeDomain?) {
        guard domain?.includesSnippets ?? true else { return }
        if domain == .all {
            // Full data erasure is different from ordinary sidebar refresh:
            // no in-memory draft or undo payload may restore erased content.
            saveTask?.cancel()
            saveTask = nil
            queryTask?.cancel()
            queryTask = nil
            removedSnippet = nil
            selectedSnippetID = nil
            activeFolderID = nil
            folderPendingDeletion = nil
            folderPendingDeletionCount = nil
            folderNameDraft = ""
            folderEditorError = nil
            showFolderEditor = false
            showFolderDeleteAlert = false
            showDeleteSnippetAlert = false
            query = ""
            clearEditor()
        }
        reload()
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

    @discardableResult
    func openSnippet(id: Int64) -> Bool {
        guard flushPendingSave() else { return false }
        do {
            guard try storage.fetchSnippet(id: id) != nil else {
                message = "Сниппет уже удалён"
                return false
            }
            query = ""
            reload(selecting: id)
            return selectedSnippetID == id
        } catch {
            message = "Не удалось открыть сниппет"
            return false
        }
    }

    func snippets(in folderID: Int64?) -> [SnippetSummary] {
        guard let folderID else { return unfiledSnippets }
        return snippetsByFolderID[folderID] ?? []
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
            message = SnippetStorageError.userFacingMessage(for: error, fallback: "Не удалось создать сниппет. Повторите попытку.")
        }
    }

    func requestNewFolder() {
        guard flushPendingSave() else { return }
        editingFolderID = nil
        folderNameDraft = ""
        folderEditorError = nil
        showFolderEditor = true
    }

    func requestRename(_ folder: SnippetFolder) {
        guard flushPendingSave() else { return }
        editingFolderID = folder.id
        folderNameDraft = folder.title
        folderEditorError = nil
        showFolderEditor = true
    }

    func cancelFolderEditing() {
        showFolderEditor = false
        folderNameDraft = ""
        folderEditorError = nil
        editingFolderID = nil
    }

    func saveFolder() {
        let title = folderNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            folderEditorError = "Введите название папки"
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
            showFolderEditor = false
            folderEditorError = nil
            reload(reloadEditor: false)
        } catch {
            folderEditorError = SnippetStorageError.userFacingMessage(for: error, fallback: "Не удалось сохранить папку. Повторите попытку.")
        }
    }

    func requestDelete(_ folder: SnippetFolder) {
        guard flushPendingSave() else { return }
        guard let id = folder.id else { return }
        do {
            folderPendingDeletionCount = try storage.snippetCount(inFolder: id)
        } catch {
            message = "Не удалось проверить содержимое папки"
            return
        }
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
        guard flushPendingSave(), let id = selectedSnippetID else { return }
        saveTask?.cancel()
        saveTask = nil
        do {
            guard let removed = try storage.removeSnippet(id: id) else {
                throw SnippetStorageError.snippetNotFound
            }
            removedSnippet = removed
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

    func duplicateSelected() {
        guard flushPendingSave(), let id = selectedSnippetID else { return }
        do {
            let duplicate = try storage.duplicateSnippet(id: id)
            query = ""
            reload(selecting: duplicate.id)
        } catch {
            message = "Не удалось создать копию сниппета"
        }
    }

    func undoSnippetDeletion() {
        guard flushPendingSave(), let removedSnippet else { return }
        do {
            try storage.restoreSnippet(removedSnippet)
            self.removedSnippet = nil
            query = ""
            reload(selecting: removedSnippet.item.id)
        } catch {
            message = "Не удалось восстановить сниппет. Проверьте, не занят ли его ключ поиска."
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
        do {
            guard let snippet = try storage.fetchSnippet(id: id) else {
                message = "Сниппет уже удалён"
                reload()
                return
            }
            applyLoadedSnippet(snippet)
        } catch {
            selectedSnippetID = nil
            clearEditor()
            message = "Не удалось открыть сниппет"
        }
    }

    private func applyLoadedSnippet(_ snippet: Snippet) {
        isLoadingEditor = true
        defer { isLoadingEditor = false }
        editingSnippet = snippet
        activeFolderID = snippet.folderID
        editorTitle = snippet.title
        editorKeyword = snippet.keyword ?? ""
        editorContent = snippet.content
        editorPinned = snippet.isPinned
        editorFolderID = snippet.folderID
        pendingDraft = nil
        saveState = .saved
    }

    private func refreshCleanEditor(id: Int64) {
        guard pendingDraft == nil else { return }
        do {
            guard let latest = try storage.fetchSnippet(id: id) else { return }
            // Usage counters/timestamps can change after every paste. Do not
            // reset the text editor/caret for those background-only changes.
            if latest.title != editingSnippet?.title
                || latest.content != editingSnippet?.content
                || latest.keyword != editingSnippet?.keyword
                || latest.folderID != editingSnippet?.folderID
                || latest.isPinned != editingSnippet?.isPinned {
                applyLoadedSnippet(latest)
            }
        } catch {
            message = "Не удалось обновить сниппет"
        }
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
                snippets[index] = SnippetSummary(snippet: saved)
                rebuildSnippetIndex()
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
            message = SnippetStorageError.userFacingMessage(for: error, fallback: "Не удалось сохранить сниппет. Черновик сохранён для повтора.")
            return false
        }
    }

    private func normalizedKeyword(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        return trimmed.hasPrefix(";") ? trimmed : ";\(trimmed)"
    }

    private func rebuildSnippetIndex() {
        let ordered = snippets.sorted {
            if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
            return ($0.id ?? 0) < ($1.id ?? 0)
        }
        snippetsByFolderID = Dictionary(grouping: ordered.compactMap { summary in
            summary.folderID.map { ($0, summary) }
        }, by: \.0).mapValues { $0.map(\.1) }
        unfiledSnippets = ordered.filter { $0.folderID == nil }
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
    @FocusState private var searchIsFocused: Bool

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
        .onReceive(NotificationCenter.default.publisher(for: .neClipStorageDidChange)) { notification in
            model.storageDidChange(StorageChangeDomain.from(notification))
        }
        .onChange(of: model.query) { _, _ in model.scheduleQueryReload() }
        .onChange(of: model.editorTitle) { _, _ in model.editorChanged() }
        .onChange(of: model.editorKeyword) { _, _ in model.editorChanged() }
        .onChange(of: model.editorContent) { _, _ in model.editorChanged() }
        .onChange(of: model.editorPinned) { _, _ in model.editorChanged() }
        .onChange(of: model.editorFolderID) { _, _ in model.editorChanged() }
        .alert("Удалить сниппет?", isPresented: $model.showDeleteSnippetAlert) {
            Button("Удалить", role: .destructive, action: model.deleteSelected)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("После удаления можно нажать «Вернуть сниппет» внизу списка.")
        }
        .sheet(isPresented: $model.showFolderEditor) {
            VStack(alignment: .leading, spacing: 12) {
                Text(model.folderEditorTitle).font(.headline)
                TextField("Название папки", text: $model.folderNameDraft)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Название папки")
                if let error = model.folderEditorError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Spacer()
                    Button("Отмена", role: .cancel, action: model.cancelFolderEditing)
                        .keyboardShortcut(.cancelAction)
                    Button("Сохранить", action: model.saveFolder)
                        .keyboardShortcut(.defaultAction)
                        .disabled(!model.canSaveFolder)
                }
            }
            .padding(20)
            .frame(width: 360)
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
            HStack(spacing: 6) {
                Button { searchIsFocused = true } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("f", modifiers: .command)
                .help("Поиск по названию, тексту, ключу и папке · ⌘F")
                .accessibilityLabel("Найти сниппет")
                TextField("Поиск сниппетов и папок", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .focused($searchIsFocused)
                if !model.query.isEmpty {
                    Button { model.query = ""; searchIsFocused = true } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Очистить поиск сниппетов")
                }
            }

            List(selection: Binding(
                get: { model.selectedSnippetID },
                set: { id in
                    // NSTableView calls the binding while its delegate is
                    // updating selection. Defer storage/editor mutation one
                    // main-loop turn to avoid reentrant table operations.
                    DispatchQueue.main.async { model.selectSnippet(id) }
                }
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
                Button(action: model.createSnippetInActiveFolder) {
                    Label("Новый", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Создать сниппет в текущей папке · ⌘N")
                Button(action: model.requestNewFolder) {
                    Label("Папка…", systemImage: "folder.badge.plus")
                }
                .help("Создать папку для сниппетов")
                .accessibilityLabel("Создать папку для сниппетов")

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
            if model.removedSnippet != nil {
                Button(action: model.undoSnippetDeletion) {
                    Label("Вернуть сниппет", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                snippetRows(items)
            }
        } header: {
            HStack(spacing: 6) {
                Label(folder.title, systemImage: "folder")
                    .lineLimit(1)
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
                snippetRows(items)
            }
        } header: {
            HStack {
                Label("Без папки", systemImage: "tray")
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
                snippetRows(model.snippets, showsFolder: true)
            }
        }
    }

    private func snippetRows(_ snippets: [SnippetSummary], showsFolder: Bool = false) -> some View {
        ForEach(snippets) { snippet in
            if let id = snippet.id {
                snippetRow(snippet, folderSubtitle: showsFolder ? model.folderTitle(for: snippet.folderID) : nil)
                    .tag(id)
            }
        }
    }

    private func snippetRow(_ snippet: SnippetSummary, folderSubtitle: String? = nil) -> some View {
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
        .help("Редактировать сниппет справа")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Сниппет \(snippet.title.isEmpty ? "Без названия" : snippet.title)")
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
                    Label("Редактирование", systemImage: "pencil")
                        .font(.headline)
                    Spacer()
                    Button(action: model.duplicateSelected) {
                        Label("Дублировать", systemImage: "doc.on.doc")
                    }
                    .keyboardShortcut("d", modifiers: .command)
                    .help("Создать копию без повторения ключа поиска · ⌘D")
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
                        .help("Для быстрого поиска в меню NeClip")
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
                    Text("Подстановки: {date}, {time}, {clipboard}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Также: {date:iso} — 2026-09-05; {time:iso} — 14:30:00. Двойные скобки {{date}} вставят буквальный {date}. Итог — не более 2 МБ.")
                    Spacer()
                    saveStatus
                }
                if let message = model.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
        } else {
            switch model.emptyEditorState {
            case .emptyLibrary:
                ContentUnavailableView {
                    Label("Сниппетов пока нет", systemImage: "scissors")
                } description: {
                    Text("Создайте первый сниппет — поля редактирования сразу появятся здесь.")
                } actions: {
                    Button("Создать сниппет без папки") { model.createSnippet(in: nil) }
                    Button("Создать папку", action: model.requestNewFolder)
                }
            case .chooseSnippet:
                ContentUnavailableView {
                    Label("Выберите сниппет слева", systemImage: "cursorarrow.click")
                } description: {
                    Text("Его название, папка и текст появятся здесь для редактирования.")
                }
            case .noSearchResults:
                ContentUnavailableView {
                    Label("Ничего не найдено", systemImage: "magnifyingglass")
                } description: {
                    Text("Измените запрос или покажите всю библиотеку.")
                } actions: {
                    Button("Очистить поиск") { model.query = "" }
                }
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
