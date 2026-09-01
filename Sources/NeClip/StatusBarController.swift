import AppKit

/// The default NeClip interface is a classic native menu: recent history is
/// visible immediately, older entries are grouped by tens, and snippets live
/// in explicit folder submenus. Search stays inside the menu itself.
@MainActor
final class StatusBarController: NSObject {
    private enum MenuKind: Equatable {
        case history
        case snippets
    }

    private enum SearchEntry {
        case clip(ClipSummary)
        case snippet(Snippet)
    }

    private enum UndoDeletion: Sendable {
        case clip(RemovedClip)
        case snippet(RemovedSnippet)
    }

    private struct MenuSnapshot {
        let clips: [ClipSummary]
        let folders: [SnippetFolder]
        let snippets: [Snippet]
        let hasMorePinned: Bool
        let hasMoreHistory: Bool
    }

    private let statusItem: NSStatusItem
    private let dataQueue = DispatchQueue(label: "org.affpapa.neclip.menu-data", qos: .userInitiated)
    private var snapshot = MenuSnapshot(
        clips: [],
        folders: [],
        snippets: [],
        hasMorePinned: false,
        hasMoreHistory: false
    )
    private var snapshotIsReady = false
    private var refreshGeneration = 0
    private var pendingPresentation: (kind: MenuKind, anchoredToStatusItem: Bool)?
    private var targetPID: pid_t?
    private var feedbackWorkItem: DispatchWorkItem?
    private var transientStatus: String?
    private weak var activeMenu: NSMenu?
    private weak var activeSearchField: MenuSearchField?
    private var activeMenuKind: MenuKind?
    private var searchGeneration = 0
    private var searchWorkItem: DispatchWorkItem?
    private var snapshotRefreshWorkItem: DispatchWorkItem?
    private var visibleKeyboardEntries: [SearchEntry] = []
    private var undoDeletion: UndoDeletion?
    private var hotKeyWarnings: [String] = []

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemPressed(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "NeClip — \(Settings.historyShortcut.displayString)"
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureControlsChanged),
            name: .neClipCaptureControlsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureDidFail(_:)),
            name: .neClipCaptureDidFail,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(captureDidSkip(_:)),
            name: .neClipCaptureDidSkip,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageDidChange),
            name: .neClipStorageDidChange,
            object: nil
        )
        refreshIcon()
        statusItem.isVisible = true
        refreshSnapshot()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// The history shortcut shows the native menu at the pointer, like ClipMenu/Clipy.
    func showHistory() {
        show(.history, anchoredToStatusItem: false)
    }

    /// The snippets shortcut opens the snippet folders directly.
    func showSnippets() {
        show(.snippets, anchoredToStatusItem: false)
    }

    func refreshAuthorizationState() {
        refreshIcon()
    }

    func refreshShortcutPresentation() {
        refreshIcon()
    }

    func setHotKeyWarnings(_ warnings: [String]) {
        hotKeyWarnings = warnings
    }

    func showLayoutFeedback(_ message: String) {
        showFeedback(message)
        Task { @MainActor in LayoutFeedbackHUD.shared.show(message) }
    }

    @objc private func storageDidChange() {
        scheduleSnapshotRefresh()
    }

    @objc private func statusItemPressed(_ sender: NSStatusBarButton) {
        show(.history, anchoredToStatusItem: true)
    }

    private func show(_ kind: MenuKind, anchoredToStatusItem: Bool) {
        targetPID = captureTargetPID()
        guard snapshotIsReady else {
            pendingPresentation = (kind, anchoredToStatusItem)
            refreshSnapshot()
            return
        }
        present(kind, anchoredToStatusItem: anchoredToStatusItem)
    }

    private func present(_ kind: MenuKind, anchoredToStatusItem: Bool) {
#if DEBUG
        if ProcessInfo.processInfo.environment["NECLIP_UI_TEST_REGULAR"] == "1"
            || ProcessInfo.processInfo.environment["NECLIP_UI_TEST_TAB"] != nil {
            NSApp.activate(ignoringOtherApps: true)
        }
#endif
        activeMenuKind = kind
        let menu = kind == .history ? buildHistoryMenu() : buildSnippetsMenu(asRoot: true)
        MenuAppearance.applyEffectiveAppearance(to: menu)
        activeMenu = menu
        if let searchField = activeSearchField {
            DispatchQueue.main.async { [weak searchField] in
                searchField?.window?.makeFirstResponder(searchField)
            }
        }
        if anchoredToStatusItem, let button = statusItem.button {
            menu.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: button.bounds.minY - 4),
                in: button
            )
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
        activeMenu = nil
        activeSearchField = nil
        activeMenuKind = nil
        visibleKeyboardEntries = []
        searchWorkItem?.cancel()
        searchWorkItem = nil
        searchGeneration += 1
    }

    private func refreshSnapshot() {
        snapshotRefreshWorkItem?.cancel()
        snapshotRefreshWorkItem = nil
        refreshGeneration += 1
        let generation = refreshGeneration
        dataQueue.async { [weak self] in
            do {
                let pinned = try Storage.shared.summaries(
                    limit: 101,
                    search: nil,
                    pinnedOnly: true
                )
                let recent = try Storage.shared.summaries(
                    limit: 101,
                    search: nil,
                    pinnedOnly: false,
                    unpinnedOnly: true
                )
                let folders = try Storage.shared.snippetFolders()
                let snippets = try Storage.shared.allSnippets(search: nil, pinnedOnly: false)
                let loaded = MenuSnapshot(
                    clips: Array(pinned.prefix(100)) + Array(recent.prefix(100)),
                    folders: folders,
                    snippets: snippets,
                    hasMorePinned: pinned.count > 100,
                    hasMoreHistory: recent.count > 100
                )
                DispatchQueue.main.async {
                    guard let self, generation == self.refreshGeneration else { return }
                    self.snapshot = loaded
                    self.snapshotIsReady = true
                    if let pending = self.pendingPresentation {
                        self.pendingPresentation = nil
                        self.present(pending.kind, anchoredToStatusItem: pending.anchoredToStatusItem)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, generation == self.refreshGeneration else { return }
                    self.snapshotIsReady = true
                    self.showFeedback("Не удалось обновить меню")
                    if let pending = self.pendingPresentation {
                        self.pendingPresentation = nil
                        self.present(pending.kind, anchoredToStatusItem: pending.anchoredToStatusItem)
                    }
                }
            }
        }
    }

    /// Insert and OCR completion often arrive as a short notification burst.
    /// Collapse that burst into one database snapshot without delaying a menu
    /// explicitly requested by the user.
    private func scheduleSnapshotRefresh() {
        snapshotRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshSnapshot()
        }
        snapshotRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(35), execute: workItem)
    }

    private func buildHistoryMenu() -> NSMenu {
        let menu = makeMenu(title: "NeClip")
        menu.addItem(makeSearchItem(placeholder: "Поиск по истории…"))
        menu.addItem(.separator())
        appendHistoryContents(to: menu)
        return menu
    }

    private func appendHistoryContents(to menu: NSMenu) {
        if let transientStatus {
            let status = NSMenuItem(title: transientStatus, action: nil, keyEquivalent: "")
            status.image = symbol("info.circle", description: nil)
            menu.addItem(status)
            menu.addItem(.separator())
        }
        if Storage.shared.startupError != nil {
            let warning = NSMenuItem(title: "База недоступна — история только до выхода", action: nil, keyEquivalent: "")
            warning.image = symbol("exclamationmark.triangle.fill", description: "Ошибка базы")
            menu.addItem(warning)
            menu.addItem(.separator())
        }
        appendHotKeyWarnings(to: menu)

        switch ClipboardAccess.current {
        case .denied:
            let warning = NSMenuItem(title: "История заблокирована macOS", action: nil, keyEquivalent: "")
            warning.image = symbol("exclamationmark.shield.fill", description: "Доступ к буферу запрещён")
            menu.addItem(warning)
            menu.addItem(item(
                "Открыть «Конфиденциальность и безопасность»…",
                #selector(openClipboardPrivacy),
                symbol: "gearshape"
            ))
            menu.addItem(.separator())
        case .needsChoice:
            let warning = NSMenuItem(
                title: "Для непрерывной истории выберите «Всегда разрешать»",
                action: nil,
                keyEquivalent: ""
            )
            warning.image = symbol("info.circle", description: nil)
            menu.addItem(warning)
            menu.addItem(item(
                "Настроить доступ к буферу…",
                #selector(openClipboardPrivacy),
                symbol: "hand.raised"
            ))
            menu.addItem(.separator())
        case .unrestricted, .allowed:
            break
        }

        if !PasteService.isAccessibilityTrusted {
            menu.addItem(NSMenuItem(title: "Автовставка выключена — выбранное будет скопировано", action: nil, keyEquivalent: ""))
            menu.addItem(item("Разрешить автовставку…", #selector(requestAccessibility), symbol: "hand.raised"))
            menu.addItem(.separator())
        }

        let pinned = Array(snapshot.clips.filter(\.isPinned).prefix(100))
        if !pinned.isEmpty {
            let pinnedItem = item("Закреплённые", nil, symbol: "pin.fill")
            let pinnedMenu = makeMenu(title: "Закреплённые")
            for (index, clip) in pinned.prefix(10).enumerated() {
                pinnedMenu.addItem(clipMenuItem(clip, absoluteIndex: index, quickKey: nil, showNumber: false))
            }
            if pinned.count > 10 {
                for start in stride(from: 10, to: pinned.count, by: 10) {
                    let end = min(start + 10, pinned.count)
                    let rangeItem = item("\(start + 1)–\(end)", nil, symbol: "folder")
                    let submenu = makeMenu(title: "Закреплённые \(start + 1)–\(end)")
                    for index in start..<end {
                        submenu.addItem(clipMenuItem(
                            pinned[index],
                            absoluteIndex: index,
                            quickKey: nil,
                            showNumber: false
                        ))
                    }
                    rangeItem.submenu = submenu
                    pinnedMenu.addItem(rangeItem)
                }
            }
            if snapshot.hasMorePinned {
                pinnedMenu.addItem(.separator())
                pinnedMenu.addItem(NSMenuItem(
                    title: "Остальные — через поиск is:pinned",
                    action: nil,
                    keyEquivalent: ""
                ))
            }
            pinnedItem.submenu = pinnedMenu
            menu.addItem(pinnedItem)
            menu.addItem(.separator())
        }

        menu.addItem(.sectionHeader(title: "История"))
        let history = Array(snapshot.clips.filter { !$0.isPinned }.prefix(100))
        let firstPage = Array(history.prefix(10))
        visibleKeyboardEntries = firstPage.map(SearchEntry.clip)
        if firstPage.isEmpty {
            let empty = NSMenuItem(title: "История пуста — скопируйте текст, изображение или файл", action: nil, keyEquivalent: "")
            empty.image = symbol("doc.on.clipboard", description: nil)
            menu.addItem(empty)
        } else {
            for (index, clip) in firstPage.enumerated() {
                menu.addItem(clipMenuItem(clip, absoluteIndex: index, quickKey: quickKey(for: index), showNumber: true))
            }
        }

        if history.count > 10 {
            let moreItem = item("Ещё из истории", nil, symbol: "clock.arrow.circlepath")
            let moreMenu = makeMenu(title: "Ещё из истории")
            for start in stride(from: 10, to: history.count, by: 10) {
                let end = min(start + 10, history.count)
                let rangeItem = item("\(start + 1)–\(end)", nil, symbol: "folder")
                let submenu = makeMenu(title: "\(start + 1)–\(end)")
                for index in start..<end {
                    submenu.addItem(clipMenuItem(history[index], absoluteIndex: index, quickKey: nil, showNumber: true))
                }
                rangeItem.submenu = submenu
                moreMenu.addItem(rangeItem)
            }
            moreItem.submenu = moreMenu
            menu.addItem(moreItem)
        }
        if snapshot.hasMoreHistory {
            menu.addItem(NSMenuItem(
                title: "Более старые элементы — через поиск выше",
                action: nil,
                keyEquivalent: ""
            ))
        }
        if !firstPage.isEmpty || undoDeletion != nil {
            menu.addItem(firstResultActionsItem())
        }
        menu.addItem(.separator())

        let snippetsItem = item("Сниппеты", nil, symbol: "scissors")
        snippetsItem.submenu = buildSnippetsMenu(asRoot: false)
        menu.addItem(snippetsItem)

        appendSequentialPasteControls(to: menu)
        menu.addItem(layoutMenuItem())

        menu.addItem(.separator())
        addCaptureControls(to: menu)
        menu.addItem(item("Очистить историю…", #selector(clearHistory), symbol: "trash"))
        menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
        menu.addItem(item("Настройки…", #selector(openPreferences), symbol: "gearshape", keyEquivalent: ",", modifiers: [.command]))
        menu.addItem(item("Проверить обновления…", #selector(checkUpdates), symbol: "arrow.triangle.2.circlepath"))
        menu.addItem(.separator())
        menu.addItem(item("Выйти из NeClip", #selector(NSApplication.terminate(_:)), keyEquivalent: "q", modifiers: [.command]))
    }

    private func buildSnippetsMenu(asRoot: Bool) -> NSMenu {
        let menu = makeMenu(title: "Сниппеты")
        if asRoot {
            menu.addItem(makeSearchItem(placeholder: "Поиск сниппетов…"))
            menu.addItem(.separator())
        }
        appendSnippetContents(to: menu, showHeader: asRoot)
        return menu
    }

    private func appendSnippetContents(to menu: NSMenu, showHeader: Bool) {
        if showHeader {
            appendHotKeyWarnings(to: menu)
            let quickSnippets = Array(snapshot.snippets.prefix(9))
            visibleKeyboardEntries = quickSnippets.map(SearchEntry.snippet)
            menu.addItem(.sectionHeader(title: "Быстрые"))
            if quickSnippets.isEmpty {
                menu.addItem(NSMenuItem(title: "Сниппетов пока нет", action: nil, keyEquivalent: ""))
                menu.addItem(.separator())
                if undoDeletion != nil {
                    menu.addItem(firstResultActionsItem())
                    menu.addItem(.separator())
                }
                menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
                return
            }
            for (index, snippet) in quickSnippets.enumerated() {
                menu.addItem(snippetMenuItem(snippet, resultIndex: index, quickKey: quickKey(for: index)))
            }
            menu.addItem(firstResultActionsItem())
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "Папки"))
        }
        var addedSnippetGroup = false
        let grouped = Dictionary(grouping: snapshot.snippets, by: \.folderID)
        for folder in snapshot.folders {
            guard let folderID = folder.id, let snippets = grouped[folderID], !snippets.isEmpty else { continue }
            menu.addItem(snippetFolderItem(title: folder.title, snippets: snippets))
            addedSnippetGroup = true
        }

        let knownFolderIDs = Set(snapshot.folders.compactMap(\.id))
        let unfiled = snapshot.snippets.filter { snippet in
            guard let folderID = snippet.folderID else { return true }
            return !knownFolderIDs.contains(folderID)
        }
        if !unfiled.isEmpty {
            menu.addItem(snippetFolderItem(title: "Без папки", snippets: unfiled))
            addedSnippetGroup = true
        }

        if !addedSnippetGroup {
            menu.addItem(NSMenuItem(title: "Сниппетов пока нет", action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
    }

    private func makeSearchItem(placeholder: String) -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 38))
        let searchField = MenuSearchField(frame: NSRect(x: 10, y: 5, width: 340, height: 28))
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = true
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.setAccessibilityLabel(placeholder)
        searchField.toolTip = """
            Фильтры: type:text/image/file/link/email/color/code · app:имя · \
            when:today/week/month · is:pinned/history
            """
        searchField.onEscape = { [weak self, weak searchField] in
            guard let self, let searchField else { return }
            if !searchField.stringValue.isEmpty {
                searchField.stringValue = ""
                self.searchChanged("")
            } else {
                self.activeMenu?.cancelTracking()
            }
        }
        searchField.onSubmit = { [weak self] modifiers in
            self?.activateKeyboardEntry(at: 0, modifiers: modifiers)
        }
        searchField.onQuickSelect = { [weak self] index, modifiers in
            self?.activateKeyboardEntry(at: index, modifiers: modifiers.subtracting(.command))
        }
        searchField.onNavigateToMenu = { [weak searchField] in
            searchField?.window?.makeFirstResponder(nil)
        }
        searchField.onTogglePinFirst = { [weak self] in
            self?.toggleFirstResultPin()
        }
        searchField.onSaveFirstAsSnippet = { [weak self] in
            self?.saveFirstResultAsSnippet()
        }
        searchField.onDeleteFirst = { [weak self] in
            self?.deleteFirstResult()
        }
        searchField.onUndo = { [weak self] in
            self?.undoLastDeletion()
        }
        searchField.onPreviewFirst = { [weak self] in
            self?.previewFirstResult()
        }
        searchField.onOpenFirst = { [weak self] in
            self?.openFirstResult()
        }
        container.addSubview(searchField)
        let menuItem = NSMenuItem()
        menuItem.view = container
        activeSearchField = searchField
        return menuItem
    }

    private func searchChanged(_ rawQuery: String) {
        guard let menu = activeMenu, let kind = activeMenuKind else { return }
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchWorkItem?.cancel()
        searchWorkItem = nil
        searchGeneration += 1
        let generation = searchGeneration

        if query.isEmpty {
            removeDynamicItems(from: menu)
            if kind == .history {
                appendHistoryContents(to: menu)
            } else {
                appendSnippetContents(to: menu, showHeader: true)
            }
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  generation == self.searchGeneration,
                  self.activeMenu != nil else { return }
            self.dataQueue.async { [weak self] in
                guard let self else { return }
                do {
                    let parsed = ClipboardSearchQuery.parse(query)
                    let clips = kind == .history
                        ? try Storage.shared.searchSummaries(query: parsed, limit: 20)
                        : []
                    let snippets = parsed.usesStructuredFilters
                        ? []
                        : try Storage.shared.allSnippets(
                            search: parsed.terms,
                            pinnedOnly: false,
                            limit: 20
                        )
                    DispatchQueue.main.async {
                        guard generation == self.searchGeneration,
                              let menu = self.activeMenu else { return }
                        self.showSearchResults(
                            clips: clips,
                            snippets: snippets,
                            query: parsed.terms,
                            kind: kind,
                            in: menu
                        )
                    }
                } catch {
                    DispatchQueue.main.async {
                        guard generation == self.searchGeneration,
                              let menu = self.activeMenu else { return }
                        self.removeDynamicItems(from: menu)
                        self.visibleKeyboardEntries = []
                        menu.addItem(NSMenuItem(title: "Не удалось выполнить поиск", action: nil, keyEquivalent: ""))
                    }
                }
            }
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50), execute: workItem)
    }

    private func showSearchResults(
        clips: [ClipSummary],
        snippets: [Snippet],
        query: String,
        kind: MenuKind,
        in menu: NSMenu
    ) {
        removeDynamicItems(from: menu)
        menu.addItem(.sectionHeader(title: "Результаты"))

        let normalizedQuery = normalizeSearchToken(query)
        let exactSnippets = snippets.filter { normalizeSearchToken($0.keyword ?? "") == normalizedQuery }
        let exactSnippetIDs = Set(exactSnippets.compactMap(\.id))
        let remainingSnippets = snippets.filter { snippet in
            guard let id = snippet.id else { return true }
            return !exactSnippetIDs.contains(id)
        }
        var results: [SearchEntry]
        if kind == .history {
            results = exactSnippets.map(SearchEntry.snippet)
                + clips.map(SearchEntry.clip)
                + remainingSnippets.map(SearchEntry.snippet)
        } else {
            results = (exactSnippets + remainingSnippets).map(SearchEntry.snippet)
        }
        results = Array(results.prefix(20))
        visibleKeyboardEntries = results

        if results.isEmpty {
            menu.addItem(NSMenuItem(title: "Ничего не найдено", action: nil, keyEquivalent: ""))
        } else {
            for (index, result) in results.enumerated() {
                let key = quickKey(for: index)
                switch result {
                case .clip(let clip):
                    menu.addItem(clipMenuItem(clip, absoluteIndex: index, quickKey: key, showNumber: true))
                case .snippet(let snippet):
                    menu.addItem(snippetMenuItem(snippet, resultIndex: index, quickKey: key))
                }
            }
        }

        if !results.isEmpty || undoDeletion != nil {
            menu.addItem(firstResultActionsItem())
        }
        menu.addItem(.separator())
        if kind == .history {
            appendSequentialPasteControls(to: menu)
            menu.addItem(layoutMenuItem())
            menu.addItem(.separator())
            addCaptureControls(to: menu)
            menu.addItem(item("Очистить историю…", #selector(clearHistory), symbol: "trash"))
            menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
            menu.addItem(item("Настройки…", #selector(openPreferences), symbol: "gearshape", keyEquivalent: ",", modifiers: [.command]))
            menu.addItem(.separator())
            menu.addItem(item("Выйти из NeClip", #selector(NSApplication.terminate(_:)), keyEquivalent: "q", modifiers: [.command]))
        } else {
            menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
        }
    }

    private func removeDynamicItems(from menu: NSMenu) {
        while menu.numberOfItems > 2 {
            menu.removeItem(at: 2)
        }
    }

    private func normalizeSearchToken(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: ";"))
    }

    private func activateKeyboardEntry(at index: Int, modifiers: NSEvent.ModifierFlags) {
        guard visibleKeyboardEntries.indices.contains(index) else { return }
        let selected = visibleKeyboardEntries[index]
        activeMenu?.cancelTracking()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch selected {
            case .clip(let clip):
                let sender = NSMenuItem()
                sender.representedObject = NSNumber(value: clip.id)
                self.pasteClip(sender, forcedModifiers: modifiers)
            case .snippet(let snippet):
                guard let id = snippet.id else { return }
                let sender = NSMenuItem()
                sender.representedObject = NSNumber(value: id)
                self.pasteSnippet(sender, forcedModifiers: modifiers)
            }
        }
    }

    private func appendHotKeyWarnings(to menu: NSMenu) {
        guard !hotKeyWarnings.isEmpty else { return }
        let root = item("Некоторые быстрые клавиши заняты", nil, symbol: "exclamationmark.triangle")
        let submenu = makeMenu(title: "Недоступные быстрые клавиши")
        for warning in hotKeyWarnings {
            submenu.addItem(NSMenuItem(title: warning, action: nil, keyEquivalent: ""))
        }
        root.submenu = submenu
        menu.addItem(root)
        menu.addItem(.separator())
    }

    private func firstResultActionsItem() -> NSMenuItem {
        let hasEntry = visibleKeyboardEntries.first != nil
        let rootTitle = hasEntry
            ? "Действия с верхним элементом"
            : (undoDeletion == nil ? "Действия с верхним элементом" : "Вернуть удалённое")
        let root = item(rootTitle, nil, symbol: hasEntry ? "ellipsis.circle" : "arrow.uturn.backward")
        root.toolTip = hasEntry
            ? "Команды применяются к первому видимому элементу списка"
            : "Восстановить последний удалённый элемент"
        let submenu = makeMenu(title: rootTitle)
        if let entry = visibleKeyboardEntries.first {
            let isPinned: Bool
            switch entry {
            case .clip(let clip):
                isPinned = clip.isPinned
                submenu.addItem(item(
                    clip.kind == .text ? "Просмотреть и изменить…" : "Просмотреть и переименовать…",
                    #selector(previewFirstResult),
                    symbol: "eye",
                    keyEquivalent: "e",
                    modifiers: [.command]
                ))
                if clip.kind == .file || SmartClipClassifier.category(for: clip) == .link {
                    submenu.addItem(item(
                        "Открыть",
                        #selector(openFirstResult),
                        symbol: "arrow.up.forward.app",
                        keyEquivalent: "o",
                        modifiers: [.command]
                    ))
                }
                if clip.kind == .image, !(clip.text ?? "").isEmpty {
                    submenu.addItem(item(
                        "Вставить распознанный текст",
                        #selector(pasteFirstResultOCR),
                        symbol: "text.viewfinder"
                    ))
                }
                submenu.addItem(.separator())
            case .snippet(let snippet):
                isPinned = snippet.isPinned
            }
            submenu.addItem(item(
                isPinned ? "Открепить" : "Закрепить",
                #selector(toggleFirstResultPin),
                symbol: isPinned ? "pin.slash" : "pin",
                keyEquivalent: "p",
                modifiers: [.command]
            ))

            if case .clip(let clip) = entry, clip.kind == .text, !(clip.text ?? "").isEmpty {
                submenu.addItem(textTransformMenuItem())
                submenu.addItem(item(
                    "Сохранить как сниппет",
                    #selector(saveFirstResultAsSnippet),
                    symbol: "scissors",
                    keyEquivalent: "s",
                    modifiers: [.command]
                ))
            }
            submenu.addItem(item(
                "Удалить",
                #selector(deleteFirstResult),
                symbol: "trash",
                keyEquivalent: "\u{8}",
                modifiers: [.command]
            ))
        } else if undoDeletion == nil {
            root.isEnabled = false
            return root
        }
        if undoDeletion != nil {
            if hasEntry { submenu.addItem(.separator()) }
            submenu.addItem(item(
                "Вернуть удалённое",
                #selector(undoLastDeletion),
                symbol: "arrow.uturn.backward",
                keyEquivalent: "z",
                modifiers: [.command]
            ))
        }
        root.submenu = submenu
        return root
    }

    @objc private func previewFirstResult() {
        guard case .clip(let clip) = visibleKeyboardEntries.first else { return }
        activeMenu?.cancelTracking()
        HistoryItemInspectorWindowController.shared.show(clipID: clip.id)
    }

    @objc private func openFirstResult() {
        guard case .clip(let summary) = visibleKeyboardEntries.first else { return }
        activeMenu?.cancelTracking()
        dataQueue.async { [weak self] in
            do {
                guard let item = try Storage.shared.fetchClip(id: summary.id),
                      let url = HistoryItemActionResolver.openTarget(for: item) else {
                    DispatchQueue.main.async { self?.showFeedback("Открывать нечего") }
                    return
                }
                DispatchQueue.main.async {
                    if NSWorkspace.shared.open(url) {
                        self?.showFeedback("Открыто")
                    } else {
                        self?.showFeedback("Не удалось открыть")
                    }
                }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось открыть элемент") }
            }
        }
    }

    @objc private func pasteFirstResultOCR() {
        guard case .clip(let summary) = visibleKeyboardEntries.first else { return }
        let capturedTargetPID = targetPID
        activeMenu?.cancelTracking()
        dataQueue.async { [weak self] in
            do {
                guard let stored = try Storage.shared.fetchClip(id: summary.id),
                      stored.kind == .image,
                      let ocrText = stored.ocrText?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !ocrText.isEmpty else {
                    DispatchQueue.main.async { self?.showFeedback("Распознанного текста нет") }
                    return
                }
                let textItem = ClipItem(
                    kind: .text,
                    title: stored.title,
                    text: ocrText,
                    createdAt: stored.createdAt
                )
                DispatchQueue.main.async {
                    PasteService.paste(
                        textItem,
                        plainText: true,
                        targetPID: capturedTargetPID
                    ) { [weak self] result in
                        self?.handlePasteResult(result)
                    }
                }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось открыть распознанный текст") }
            }
        }
    }

    private func textTransformMenuItem() -> NSMenuItem {
        let root = item("Преобразовать и вставить", nil, symbol: "textformat")
        let submenu = makeMenu(title: "Преобразовать и вставить")
        for transform in TextTransform.allCases {
            let entry = item(transform.title, #selector(applyTransformToFirstResult(_:)))
            entry.representedObject = transform.rawValue
            submenu.addItem(entry)
            if transform == .titleCase || transform == .sortLines || transform == .urlDecode {
                submenu.addItem(.separator())
            }
        }
        root.submenu = submenu
        return root
    }

    @objc private func applyTransformToFirstResult(_ sender: NSMenuItem) {
        guard case .clip(let summary) = visibleKeyboardEntries.first,
              let rawValue = sender.representedObject as? String,
              let transform = TextTransform(rawValue: rawValue) else { return }
        let capturedTargetPID = targetPID
        activeMenu?.cancelTracking()
        dataQueue.async { [weak self] in
            do {
                guard let stored = try Storage.shared.fetchClip(id: summary.id),
                      stored.kind == .text,
                      let text = stored.text else { return }
                let transformed = try transform.apply(to: text)
                guard !transformed.isEmpty else {
                    DispatchQueue.main.async { self?.showFeedback("Преобразование дало пустой текст") }
                    return
                }
                let item = ClipItem(kind: .text, title: stored.title, text: transformed, createdAt: stored.createdAt)
                DispatchQueue.main.async {
                    PasteService.paste(item, plainText: true, targetPID: capturedTargetPID) { [weak self] result in
                        self?.handlePasteResult(result)
                    }
                }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Этот текст нельзя преобразовать") }
            }
        }
    }

    private func appendSequentialPasteControls(to menu: NSMenu) {
        let sequence = SequentialPasteSequence.shared.snapshot()
        let title = sequence.isActive
            ? "Вставить следующее · \(sequence.position + 1) из \(sequence.total)"
            : "Последовательная вставка"
        menu.addItem(item(
            title,
            #selector(pasteNextSequentiallyFromMenu),
            symbol: "arrow.right.to.line",
            keyEquivalent: HotKeyCoordinator.shared.shortcut(for: .sequentialPaste).keyEquivalent ?? "",
            modifiers: HotKeyCoordinator.shared.shortcut(for: .sequentialPaste).nsEventModifiers
        ))
        if sequence.isActive {
            menu.addItem(item(
                "Сбросить последовательность",
                #selector(resetSequentialPaste),
                symbol: "arrow.counterclockwise"
            ))
        }
    }

    @objc private func pasteNextSequentiallyFromMenu() {
        activeMenu?.cancelTracking()
        pasteNextSequentially()
    }

    @objc private func resetSequentialPaste() {
        SequentialPasteSequence.shared.reset()
        showFeedback("Последовательность сброшена")
    }

    /// The sequential shortcut walks recent history without a collection mode.
    func pasteNextSequentially() {
        let sequenceTargetPID = captureTargetPID()
        dataQueue.async { [weak self] in
            do {
                let recentIDs = try Storage.shared.recentClipIDs()
                guard let id = SequentialPasteSequence.shared.beginNext(recentIDs: recentIDs) else {
                    DispatchQueue.main.async { self?.showFeedback("История пуста") }
                    return
                }
                guard let clip = try Storage.shared.fetchClip(id: id) else {
                    SequentialPasteSequence.shared.complete(id: id, advance: true)
                    DispatchQueue.main.async { self?.pasteNextSequentially() }
                    return
                }
                DispatchQueue.main.async {
                    guard SequentialPasteSequence.shared.isCurrent(id: id) else {
                        self?.showFeedback("Новая копия — последовательность обновлена")
                        return
                    }
                    PasteService.paste(clip, plainText: false, targetPID: sequenceTargetPID) { [weak self] result in
                        let succeeded: Bool
                        if case .failed = result { succeeded = false } else { succeeded = true }
                        SequentialPasteSequence.shared.complete(id: id, advance: succeeded)
                        self?.handlePasteResult(result)
                        if succeeded {
                            let remaining = SequentialPasteSequence.shared.snapshot().remaining
                            self?.showFeedback(
                                remaining > 0
                                    ? "Следующий элемент · осталось \(remaining)"
                                    : "Последовательность завершена"
                            )
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось открыть историю") }
            }
        }
    }

    @objc private func toggleFirstResultPin() {
        guard let entry = visibleKeyboardEntries.first else { return }
        activeMenu?.cancelTracking()
        dataQueue.async { [weak self] in
            do {
                let pinned: Bool
                switch entry {
                case .clip(let clip):
                    pinned = !clip.isPinned
                    try Storage.shared.setPinned(id: clip.id, pinned: pinned)
                case .snippet(let snippet):
                    guard let id = snippet.id else { return }
                    pinned = !snippet.isPinned
                    try Storage.shared.setSnippetPinned(id: id, pinned: pinned)
                }
                DispatchQueue.main.async {
                    self?.showFeedback(pinned ? "Закреплено" : "Откреплено")
                }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось изменить закрепление") }
            }
        }
    }

    @objc private func saveFirstResultAsSnippet() {
        guard case .clip(let summary) = visibleKeyboardEntries.first else { return }
        activeMenu?.cancelTracking()
        dataQueue.async { [weak self] in
            do {
                guard let clip = try Storage.shared.fetchClip(id: summary.id) else {
                    DispatchQueue.main.async { self?.showFeedback("Элемент уже удалён") }
                    return
                }
                guard let content = clip.text, !content.isEmpty else {
                    DispatchQueue.main.async { self?.showFeedback("Сниппет можно создать только из текста") }
                    return
                }
                _ = try Storage.shared.addSnippet(
                    folderID: nil,
                    title: String(summary.title.prefix(60)),
                    content: content
                )
                DispatchQueue.main.async { self?.showFeedback("Сохранено в «Без папки»") }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось создать сниппет") }
            }
        }
    }

    @objc private func deleteFirstResult() {
        guard let entry = visibleKeyboardEntries.first else { return }
        activeMenu?.cancelTracking()
        dataQueue.async { [weak self] in
            do {
                let removed: UndoDeletion?
                switch entry {
                case .clip(let clip):
                    removed = try Storage.shared.removeClip(id: clip.id).map(UndoDeletion.clip)
                case .snippet(let snippet):
                    guard let id = snippet.id else { return }
                    removed = try Storage.shared.removeSnippet(id: id).map(UndoDeletion.snippet)
                }
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard let removed else {
                        self.showFeedback("Элемент уже удалён")
                        return
                    }
                    self.undoDeletion = removed
                    self.showFeedback("Удалено — ⌘Z вернуть")
                }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось удалить") }
            }
        }
    }

    @objc private func undoLastDeletion() {
        guard let removed = undoDeletion else { return }
        undoDeletion = nil
        activeMenu?.cancelTracking()
        dataQueue.async { [weak self] in
            do {
                switch removed {
                case .clip(let clip):
                    try Storage.shared.restoreClip(clip)
                case .snippet(let snippet):
                    try Storage.shared.restoreSnippet(snippet)
                }
                DispatchQueue.main.async { self?.showFeedback("Восстановлено") }
            } catch {
                DispatchQueue.main.async {
                    self?.undoDeletion = removed
                    self?.showFeedback("Не удалось восстановить")
                }
            }
        }
    }

    private func snippetFolderItem(title: String, snippets: [Snippet]) -> NSMenuItem {
        let displayTitle = cleanTitle(title)
        let folderItem = item(displayTitle, nil, symbol: "folder")
        let submenu = makeMenu(title: displayTitle)
        for snippet in snippets {
            submenu.addItem(snippetMenuItem(snippet, resultIndex: nil, quickKey: nil))
        }
        folderItem.submenu = submenu
        return folderItem
    }

    private func snippetMenuItem(_ snippet: Snippet, resultIndex: Int?, quickKey: String?) -> NSMenuItem {
        let keyword = snippet.keyword.map { "  —  \($0)" } ?? ""
        let prefix = resultIndex.map { "\($0 + 1). " } ?? ""
        let entry = item(
            prefix + cleanTitle(snippet.title + keyword),
            quickKey == nil ? #selector(pasteSnippet(_:)) : #selector(quickPasteSnippet(_:)),
            symbol: "text.quote",
            keyEquivalent: quickKey ?? "",
            modifiers: quickKey == nil ? [] : [.command]
        )
        if let id = snippet.id {
            entry.representedObject = NSNumber(value: id)
        } else {
            entry.isEnabled = false
        }
        entry.toolTip = snippet.content
        return entry
    }

    private func clipMenuItem(
        _ clip: ClipSummary,
        absoluteIndex: Int,
        quickKey: String?,
        showNumber: Bool
    ) -> NSMenuItem {
        let prefix = showNumber ? "\(absoluteIndex + 1). " : ""
        let entry = item(
            prefix + cleanTitle(clip.title),
            quickKey == nil ? #selector(pasteClip(_:)) : #selector(quickPasteClip(_:)),
            symbol: symbolName(for: clip),
            keyEquivalent: quickKey ?? "",
            modifiers: quickKey == nil ? [] : [.command]
        )
        entry.representedObject = NSNumber(value: clip.id)
        entry.toolTip = clip.kind == .text
            ? "\(clip.text ?? "")\n⌃ — исправить раскладку перед вставкой"
            : clip.text
        return entry
    }

    private func layoutMenuItem() -> NSMenuItem {
        let root = item("Раскладка", nil, symbol: "character.cursor.ibeam")
        let submenu = makeMenu(title: "Раскладка")
        let shortcuts = HotKeyCoordinator.shared
        let automatic = item(
            "Автоматически исправлять (бета)",
            #selector(toggleAutomaticLayoutCorrection),
            symbol: "wand.and.stars"
        )
        automatic.state = Settings.automaticLayoutCorrection ? .on : .off
        submenu.addItem(automatic)
        let disableShortcut = shortcuts.shortcut(for: .disableAutomaticCorrection)
        let disable = item(
            "Быстро выключить автоисправление",
            #selector(disableAutomaticLayoutCorrection),
            symbol: "stop.circle",
            keyEquivalent: disableShortcut.keyEquivalent ?? "",
            modifiers: disableShortcut.nsEventModifiers
        )
        disable.isEnabled = Settings.automaticLayoutCorrection
        submenu.addItem(disable)
        let manualShortcut = shortcuts.shortcut(for: .manualCorrection)
        submenu.addItem(item(
            "Исправить выделение или последнее слово",
            #selector(correctFocusedLayout),
            symbol: "text.cursor",
            keyEquivalent: manualShortcut.keyEquivalent ?? "",
            modifiers: manualShortcut.nsEventModifiers
        ))
        submenu.addItem(.separator())
        let hint = NSMenuItem(title: "⌃↩ — исправить выбранную запись истории и вставить", action: nil, keyEquivalent: "")
        hint.image = symbol("info.circle", description: nil)
        submenu.addItem(hint)
        root.submenu = submenu
        return root
    }

    private func addCaptureControls(to menu: NSMenu) {
        if ClipboardAccess.current == .denied {
            let status = NSMenuItem(title: "Запись истории недоступна", action: nil, keyEquivalent: "")
            status.image = symbol("exclamationmark.shield", description: nil)
            menu.addItem(status)
        } else if Settings.isCapturePaused {
            let status = NSMenuItem(title: "Запись истории приостановлена", action: nil, keyEquivalent: "")
            status.state = .on
            menu.addItem(status)
            menu.addItem(item("Возобновить запись", #selector(resumeCapture), symbol: "play.fill"))
        } else {
            let ignoreTitle = Settings.ignoreNextCopy
                ? "Следующая копия будет пропущена"
                : "Не сохранять следующее копирование"
            let ignore = item(ignoreTitle, #selector(ignoreNextCopy), symbol: "forward.end")
            ignore.state = Settings.ignoreNextCopy ? .on : .off
            menu.addItem(ignore)
            let pause = item("Приостановить запись", nil, symbol: "pause.fill")
            let pauseMenu = makeMenu(title: "Приостановить запись")
            pauseMenu.addItem(item("На 15 минут", #selector(pauseForFifteenMinutes), symbol: "timer"))
            pauseMenu.addItem(item("До возобновления", #selector(pauseIndefinitely), symbol: "pause.fill"))
            pause.submenu = pauseMenu
            menu.addItem(pause)
        }
    }

    private func item(
        _ title: String,
        _ action: Selector?,
        symbol symbolName: String? = nil,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        menuItem.target = action == nil ? nil : self
        menuItem.keyEquivalentModifierMask = modifiers
        if let symbolName {
            menuItem.image = symbol(symbolName, description: nil)
        }
        return menuItem
    }

    private func makeMenu(title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        menu.appearance = NSApp.effectiveAppearance
        return menu
    }

    private func symbol(_ name: String, description: String?) -> NSImage? {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: description)
        image?.isTemplate = true
        return image
    }

    private func symbolName(for kind: ClipKind) -> String {
        switch kind {
        case .text: "doc.plaintext"
        case .image: "photo"
        case .file: "doc"
        }
    }

    private func symbolName(for clip: ClipSummary) -> String {
        switch SmartClipClassifier.category(for: clip) {
        case .link?: "link"
        case .email?: "envelope"
        case .color?: "paintpalette"
        case .code?: "chevron.left.forwardslash.chevron.right"
        case nil: symbolName(for: clip.kind)
        }
    }

    private func quickKey(for index: Int) -> String? {
        guard (0..<9).contains(index) else { return nil }
        return String(index + 1)
    }

    private func cleanTitle(_ value: String) -> String {
        MenuTitleFormatter.format(value, limit: Settings.menuTitleLength)
    }

    private func captureTargetPID() -> pid_t? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier != Bundle.main.bundleIdentifier,
              !application.isTerminated else { return nil }
        return application.processIdentifier
    }

    @objc private func pasteClip(_ sender: NSMenuItem) {
        pasteClip(sender, forcedModifiers: nil)
    }

    @objc private func quickPasteClip(_ sender: NSMenuItem) {
        pasteClip(sender, forcedModifiers: NSEvent.modifierFlags.subtracting(.command))
    }

    private func pasteClip(_ sender: NSMenuItem, forcedModifiers: NSEvent.ModifierFlags?) {
        guard let id = (sender.representedObject as? NSNumber)?.int64Value else { return }
        let capturedTargetPID = targetPID
        let modifiers = forcedModifiers ?? NSEvent.modifierFlags
        let correctLayout = modifiers.contains(.control)
        let optionOverride = modifiers.contains(.option)
        let plainText = correctLayout || modifiers.contains(.shift)
            || (optionOverride ? !Settings.preferPlainText : Settings.preferPlainText)
        let copyOnly = modifiers.contains(.command)

        dataQueue.async { [weak self] in
            do {
                guard let clip = try Storage.shared.fetchClip(id: id) else {
                    DispatchQueue.main.async { self?.showFeedback("Элемент уже удалён") }
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    var itemToPaste = clip
                    if correctLayout {
                        guard clip.kind == .text,
                              let text = clip.text,
                              let conversion = KeyboardLayoutService.shared.convert(text) else {
                            self.showLayoutFeedback(clip.kind == .text ? "Нечего исправлять" : "Исправляется только текст")
                            return
                        }
                        itemToPaste.text = conversion.converted
                        itemToPaste.rtf = nil
                    }
                    PasteService.paste(
                        itemToPaste,
                        plainText: plainText,
                        targetPID: capturedTargetPID,
                        copyOnly: copyOnly
                    ) { [weak self] result in
                        DispatchQueue.main.async { self?.handlePasteResult(result) }
                    }
                }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось открыть элемент") }
            }
        }
    }

    @objc private func toggleAutomaticLayoutCorrection() {
        if Settings.automaticLayoutCorrection {
            NotificationCenter.default.post(
                name: .neClipDisableAutomaticLayoutCorrectionRequested,
                object: nil
            )
            return
        }
        PreferencesWindowController.shared.show()
        showLayoutFeedback("Включите автоисправление в разделе «Раскладка»")
    }

    @objc private func correctFocusedLayout() {
        NotificationCenter.default.post(name: .neClipManualLayoutCorrectionRequested, object: nil)
    }

    @objc private func disableAutomaticLayoutCorrection() {
        NotificationCenter.default.post(
            name: .neClipDisableAutomaticLayoutCorrectionRequested,
            object: nil
        )
    }

    @objc private func pasteSnippet(_ sender: NSMenuItem) {
        pasteSnippet(sender, forcedModifiers: nil)
    }

    @objc private func quickPasteSnippet(_ sender: NSMenuItem) {
        pasteSnippet(sender, forcedModifiers: NSEvent.modifierFlags.subtracting(.command))
    }

    private func pasteSnippet(_ sender: NSMenuItem, forcedModifiers: NSEvent.ModifierFlags?) {
        guard let id = (sender.representedObject as? NSNumber)?.int64Value,
              var snippet = snapshot.snippets.first(where: { $0.id == id }) else { return }
        let capturedTargetPID = targetPID
        let copyOnly = (forcedModifiers ?? NSEvent.modifierFlags).contains(.command)
        snippet.content = SnippetRenderer.render(
            snippet.content,
            clipboard: NSPasteboard.general.string(forType: .string)
        )

        dataQueue.async {
            try? Storage.shared.markSnippetUsed(id: id)
        }
        PasteService.paste(snippet: snippet, targetPID: capturedTargetPID, copyOnly: copyOnly) { [weak self] result in
            DispatchQueue.main.async { self?.handlePasteResult(result) }
        }
    }

    private func handlePasteResult(_ result: PasteResult) {
        targetPID = nil
        switch result {
        case .pasted:
            break
        case .copiedOnly:
            showFeedback("Скопировано")
        case .copiedOnlyNoAccessibility:
            showFeedback("Скопировано — вставьте ⌘V")
        case .copiedOnlyTargetChanged:
            showFeedback("Окно изменилось — только скопировано")
        case .failed:
            showFeedback("Не удалось скопировать")
        }
    }

    private func showFeedback(_ text: String) {
        feedbackWorkItem?.cancel()
        transientStatus = text
        statusItem.button?.toolTip = "NeClip — \(text)"
        let work = DispatchWorkItem { [weak self] in
            self?.transientStatus = nil
            self?.refreshIcon()
        }
        feedbackWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
    }

    private func refreshIcon() {
        guard let button = statusItem.button else { return }
        let symbolName: String
        if ClipboardAccess.current == .denied {
            symbolName = "exclamationmark.doc.on.clipboard"
        } else if Settings.isCapturePaused {
            symbolName = "pause.rectangle"
        } else if Settings.ignoreNextCopy {
            symbolName = "forward.end"
        } else {
            symbolName = "doc.on.clipboard"
        }
        if let image = symbol(symbolName, description: "NeClip") {
            button.image = image
            button.title = ""
        } else {
            button.title = Settings.isCapturePaused ? "Ⅱ" : (Settings.ignoreNextCopy ? "→" : "⧉")
        }
        if ClipboardAccess.current == .denied {
            button.toolTip = "NeClip — доступ к буферу запрещён"
        } else {
            if Settings.isCapturePaused {
                button.toolTip = "NeClip — запись приостановлена"
            } else if Settings.ignoreNextCopy {
                button.toolTip = "NeClip — следующее копирование будет пропущено"
            } else {
                button.toolTip = "NeClip — \(HotKeyCoordinator.shared.shortcut(for: .history).displayString)"
            }
        }
    }

    @objc private func captureControlsChanged() {
        refreshIcon()
    }

    @objc private func captureDidFail(_ notification: Notification) {
        if notification.userInfo?["error"] is StorageCapacityError {
            showFeedback("Закреплённые элементы заняли лимит — новое не сохранено")
        } else {
            showFeedback("Не удалось сохранить новое копирование")
        }
    }

    @objc private func captureDidSkip(_ notification: Notification) {
        guard let reason = notification.userInfo?["skipReason"] as? ClipboardCaptureSkipReason else { return }
        switch reason {
        case .tooLarge:
            showFeedback("Слишком большой элемент не сохранён")
        case .invalidImage:
            showFeedback("Изображение не удалось прочитать")
        case .pasteboardAccessDenied:
            refreshIcon()
        default:
            break
        }
    }

    @objc private func ignoreNextCopy() {
        Settings.ignoreNextCopy.toggle()
        refreshIcon()
        showFeedback(Settings.ignoreNextCopy ? "следующее копирование не сохранится" : "пропуск отменён")
    }

    @objc private func pauseForFifteenMinutes() {
        Settings.pauseFor15Minutes()
        refreshIcon()
        showFeedback("запись приостановлена на 15 минут")
    }

    @objc private func pauseIndefinitely() {
        Settings.pause(until: nil)
        refreshIcon()
        showFeedback("запись приостановлена")
    }

    @objc private func resumeCapture() {
        Settings.resumeCapture()
        refreshIcon()
        showFeedback("запись возобновлена")
    }

    @objc private func clearHistory() {
        let alert = NSAlert()
        alert.messageText = "Очистить историю?"
        alert.informativeText = "Незакреплённые элементы будут удалены. Сниппеты и закреплённые элементы останутся."
        alert.addButton(withTitle: "Удалить незакреплённое")
        alert.addButton(withTitle: "Отмена")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        dataQueue.async { [weak self] in
            do {
                try Storage.shared.clearHistory(includePinned: false)
                try Storage.shared.vacuum()
                DispatchQueue.main.async {
                    self?.showFeedback("история очищена")
                }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("не удалось очистить историю") }
            }
        }
    }

    @objc private func requestAccessibility() {
        PasteService.requestAccessibility()
    }

    @objc private func openClipboardPrivacy() {
        ClipboardAccess.openPrivacySettings()
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func openSnippetsEditor() {
        SnippetsEditorWindowController.shared.show()
    }

    @objc private func checkUpdates() {
        UpdateChecker.check()
    }
}

extension StatusBarController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        searchChanged(field.stringValue)
    }
}

@MainActor
private final class MenuSearchField: NSSearchField {
    var onEscape: (() -> Void)?
    var onSubmit: ((NSEvent.ModifierFlags) -> Void)?
    var onQuickSelect: ((Int, NSEvent.ModifierFlags) -> Void)?
    var onNavigateToMenu: (() -> Void)?
    var onTogglePinFirst: (() -> Void)?
    var onSaveFirstAsSnippet: (() -> Void)?
    var onDeleteFirst: (() -> Void)?
    var onUndo: (() -> Void)?
    var onPreviewFirst: (() -> Void)?
    var onOpenFirst: (() -> Void)?

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
        let character = event.charactersIgnoringModifiers ?? ""
        if modifiers.contains(.command), let number = Int(character), (1...9).contains(number) {
            onQuickSelect?(number - 1, modifiers)
            return
        }
        if modifiers == .command, !event.isARepeat {
            switch character.lowercased() {
            case "p":
                onTogglePinFirst?()
                return
            case "s":
                onSaveFirstAsSnippet?()
                return
            case "z":
                onUndo?()
                return
            case "e":
                onPreviewFirst?()
                return
            case "o":
                onOpenFirst?()
                return
            default:
                if event.keyCode == 51 {
                    onDeleteFirst?()
                    return
                }
            }
        }
        if event.keyCode == 36 || event.keyCode == 76 {
            onSubmit?(modifiers)
            return
        }
        if event.keyCode == 125 || event.keyCode == 126 {
            onNavigateToMenu?()
            return
        }
        super.keyDown(with: event)
    }
}
