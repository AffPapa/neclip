import AppKit

/// The default NeClip interface is a classic native menu: recent history is
/// visible immediately, older entries are grouped by tens, and the dedicated
/// snippets shortcut opens folder submenus before quick entries. Search stays
/// inside the menu itself.
@MainActor
final class StatusBarController: NSObject {
    private enum MenuKind: Equatable {
        case history
        case snippets
    }

    private enum SearchEntry {
        case clip(ClipSummary)
        case snippet(SnippetSummary)
    }

    private enum UndoDeletion: Sendable {
        case clip(RemovedClip)
        case snippet(RemovedSnippet)

        var generation: UUID {
            switch self {
            case .clip(let removed): removed.undoGeneration
            case .snippet(let removed): removed.undoGeneration
            }
        }
    }

    private enum HistoryCleanupWindow: Equatable {
        case lastHour
        case today
        case all

        var title: String {
            switch self {
            case .lastHour: "историю за последний час"
            case .today: "сегодняшнюю историю"
            case .all: "всю незакреплённую историю"
            }
        }

        func cutoff(now: Date = Date(), calendar: Calendar = .current) -> Date? {
            switch self {
            case .lastHour: now.addingTimeInterval(-3_600)
            case .today: calendar.startOfDay(for: now)
            case .all: nil
            }
        }
    }

    private struct MenuSnapshot {
        let clips: [ClipSummary]
        let folders: [SnippetFolder]
        let snippets: [SnippetSummary]
        let hasMorePinned: Bool
        let hasMoreHistory: Bool
        let hasMoreSnippets: Bool
    }

    private let statusItem: NSStatusItem
    private let dataQueue = DispatchQueue(label: "org.affpapa.neclip.menu-data", qos: .userInitiated)
    private var snapshot = MenuSnapshot(
        clips: [],
        folders: [],
        snippets: [],
        hasMorePinned: false,
        hasMoreHistory: false,
        hasMoreSnippets: false
    )
    private var snapshotIsReady = false
    private var refreshGeneration = 0
    private var pendingPresentation: (kind: MenuKind, anchoredToStatusItem: Bool)?
    private var targetPID: pid_t?
    private var targetBundleID: String?
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
        let observations: [(Notification.Name, Selector)] = [
            (.neClipCaptureControlsDidChange, #selector(captureControlsChanged)),
            (.neClipCaptureDidFail, #selector(captureDidFail(_:))),
            (.neClipCaptureDidSkip, #selector(captureDidSkip(_:))),
            (.neClipCaptureDidAppend, #selector(captureDidAppend)),
            (.neClipStorageDidChange, #selector(storageDidChange(_:)))
        ]
        for (name, selector) in observations {
            NotificationCenter.default.addObserver(self, selector: selector, name: name, object: nil)
        }
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

    @objc private func storageDidChange(_ notification: Notification) {
        if StorageChangeDomain.from(notification) == .all {
            undoDeletion = nil
            visibleKeyboardEntries = []
            activeMenu?.cancelTracking()
            searchWorkItem?.cancel()
            searchGeneration += 1
            refreshGeneration += 1
            snapshot = MenuSnapshot(clips: [], folders: [], snippets: [],
                                    hasMorePinned: false, hasMoreHistory: false, hasMoreSnippets: false)
            snapshotIsReady = false
            SequentialPasteSequence.shared.reset()
        }
        scheduleSnapshotRefresh()
    }

    @objc private func statusItemPressed(_ sender: NSStatusBarButton) {
        let kind: MenuKind = NSApp.currentEvent?.type == .rightMouseUp ? .snippets : .history
        show(kind, anchoredToStatusItem: true)
    }

    private func show(_ kind: MenuKind, anchoredToStatusItem: Bool) {
        // Native menus run a nested event loop. Never open a second tracking
        // session that would overwrite the first session's target and results.
        if let activeMenu {
            activeMenu.cancelTracking()
            return
        }
        let target = captureTargetApplication()
        targetPID = target?.processIdentifier
        targetBundleID = target?.bundleIdentifier
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
                let snippetSnapshot = try Storage.shared.menuSnippetSnapshot()
                let loaded = MenuSnapshot(
                    clips: Array(pinned.prefix(100)) + Array(recent.prefix(100)),
                    folders: snippetSnapshot.folders,
                    snippets: snippetSnapshot.snippets,
                    hasMorePinned: pinned.count > 100,
                    hasMoreHistory: recent.count > 100,
                    hasMoreSnippets: snippetSnapshot.hasMore
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
        menu.addItem(makeSearchItem(
            placeholder: "Поиск по истории…",
            showsHistoryFilters: true
        ))
        menu.addItem(.separator())
        appendHistoryContents(to: menu)
        return menu
    }

    private func appendHistoryContents(to menu: NSMenu) {
        if let transientStatus {
            menu.addItem(item(transientStatus, nil, symbol: "info.circle"))
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
            menu.addItem(item("Для непрерывной истории выберите «Всегда разрешать»", nil, symbol: "info.circle"))
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
            MenuPagination.appendPages(count: pinned.count, to: pinnedMenu,
                makeMenu: { self.makeMenu(title: "Закреплённые \($0)") },
                makeItem: { self.clipMenuItem(pinned[$0], absoluteIndex: $0, quickKey: nil, showNumber: false) })
            if snapshot.hasMorePinned {
                pinnedMenu.addItem(.separator())
                pinnedMenu.addItem(item("Остальные — через поиск is:pinned", nil))
            }
            pinnedItem.submenu = pinnedMenu
            menu.addItem(pinnedItem)
            menu.addItem(.separator())
        }

        menu.addItem(.sectionHeader(title: "История"))
        if RuntimeIdentity.isIsolatedPreview {
            menu.addItem(NSMenuItem(title: "Тестовая копия · отдельная история", action: nil, keyEquivalent: ""))
        }
        let history = Array(snapshot.clips.filter { !$0.isPinned }.prefix(100))
        let firstPage = Array(history.prefix(10))
        visibleKeyboardEntries = firstPage.map(SearchEntry.clip)
        if firstPage.isEmpty {
            let emptyTitle = Settings.isCapturePaused
                ? "История пуста — запись приостановлена"
                : "История пуста — скопируйте текст, изображение или файл"
            menu.addItem(item(emptyTitle, nil, symbol: "doc.on.clipboard"))
        } else {
            for (index, clip) in firstPage.enumerated() {
                menu.addItem(clipMenuItem(clip, absoluteIndex: index, quickKey: quickKey(for: index), showNumber: true))
            }
        }

        if history.count > 10 {
            let moreItem = item("Ещё из истории", nil, symbol: "clock.arrow.circlepath")
            let moreMenu = makeMenu(title: "Ещё из истории")
            MenuPagination.appendPages(count: history.count, to: moreMenu,
                makeMenu: { self.makeMenu(title: $0) },
                makeItem: { self.clipMenuItem(history[$0], absoluteIndex: $0, quickKey: nil, showNumber: true) })
            moreItem.submenu = moreMenu
            menu.addItem(moreItem)
        }
        if snapshot.hasMoreHistory {
            menu.addItem(item("Более старые элементы — через поиск выше", nil))
        }
        if !firstPage.isEmpty || undoDeletion != nil {
            menu.addItem(firstResultActionsItem())
        }
        menu.addItem(.separator())

        let snippetsItem = item("Папки сниппетов", nil, symbol: "scissors")
        applyShortcutPresentation(.snippets, to: snippetsItem)
        snippetsItem.submenu = buildSnippetsMenu(asRoot: false)
        menu.addItem(snippetsItem)

        menu.addItem(utilityMenuItem())
        menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
        Self.appendStandardFooter(to: menu, target: self)
    }

    private func buildSnippetsMenu(asRoot: Bool) -> NSMenu {
        let menu = makeMenu(title: "Сниппеты")
        if asRoot {
            menu.addItem(makeSearchItem(placeholder: "Поиск сниппетов…"))
            menu.addItem(.separator())
        }
        appendSnippetContents(to: menu, showHeader: asRoot)
        if asRoot {
            Self.appendStandardFooter(to: menu, target: self)
        }
        return menu
    }

    /// Shared by initial, loading, empty, error and result states. Explicit
    /// targets keep Quit enabled in a menu-bar-only application.
    static func appendStandardFooter(to menu: NSMenu, target: AnyObject) {
        let settings = NSMenuItem(title: "Настройки…", action: #selector(openPreferences), keyEquivalent: ",")
        settings.target = target
        settings.keyEquivalentModifierMask = [.command]
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Выйти из NeClip", action: #selector(quitApplication), keyEquivalent: "q")
        quit.target = target
        quit.keyEquivalentModifierMask = [.command]
        menu.addItem(quit)
    }

    private func appendSnippetContents(to menu: NSMenu, showHeader: Bool) {
        if showHeader {
            appendHotKeyWarnings(to: menu)
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
        if snapshot.hasMoreSnippets {
            menu.addItem(item("Остальные сниппеты — через поиск", nil))
        }

        if showHeader {
            let quickSnippets = Array(snapshot.snippets.prefix(9))
            visibleKeyboardEntries = quickSnippets.map(SearchEntry.snippet)
            if !quickSnippets.isEmpty {
                menu.addItem(.separator())
                menu.addItem(.sectionHeader(title: "Быстрый доступ"))
                for (index, snippet) in quickSnippets.enumerated() {
                    menu.addItem(snippetMenuItem(
                        snippet,
                        resultIndex: index,
                        quickKey: quickKey(for: index)
                    ))
                }
                menu.addItem(firstResultActionsItem())
            } else if undoDeletion != nil {
                menu.addItem(.separator())
                menu.addItem(firstResultActionsItem())
            }
        }

        menu.addItem(.separator())
        menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
    }

    private func applyShortcutPresentation(_ action: NeClipShortcutAction, to menuItem: NSMenuItem) {
        let shortcut = HotKeyCoordinator.shared.shortcut(for: action)
        guard let keyEquivalent = shortcut.keyEquivalent else { return }
        menuItem.keyEquivalent = keyEquivalent
        menuItem.keyEquivalentModifierMask = shortcut.nsEventModifiers
    }

    private func makeSearchItem(
        placeholder: String,
        showsHistoryFilters: Bool = false
    ) -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 38))
        let searchField = MenuSearchField(frame: NSRect(x: 10, y: 5, width: 340, height: 28))
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = true
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.setAccessibilityLabel(placeholder)
        if showsHistoryFilters {
            searchField.searchMenuTemplate = historySearchMenu()
        }
        searchField.toolTip = showsHistoryFilters ? """
            Фильтры: type:text/image/file/link/email/color/code · app:bundle.id · \
            when:today/week/month · is:pinned/history
            """ : "Поиск по названию, папке, ключу и тексту · ⌘E — редактировать первый результат · Esc — очистить поиск или закрыть меню"
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

    /// Native magnifier menu: discoverable structured filters without adding
    /// permanent controls to the compact clipboard menu.
    private func historySearchMenu() -> NSMenu {
        let menu = makeMenu(title: "Фильтры поиска")
        let filters: [(title: String, token: String)] = [
            ("Текст", "type:text"),
            ("Изображения", "type:image"),
            ("Файлы", "type:file"),
            ("Ссылки", "type:link"),
            ("Почта", "type:email"),
            ("Цвета", "type:color"),
            ("Код", "type:code"),
            ("Сегодня", "when:today"),
            ("За неделю", "when:week"),
            ("Закреплённые", "is:pinned"),
            ("Только история", "is:history")
        ]
        for filter in filters {
            let filterItem = item(filter.title, #selector(insertSearchFilter(_:)))
            filterItem.representedObject = filter.token
            filterItem.toolTip = filter.token
            menu.addItem(filterItem)
        }
        var seenBundleIDs = Set<String>()
        let recentBundleIDs = snapshot.clips.compactMap(\.appBundleID).filter { bundleID in
            seenBundleIDs.insert(bundleID.lowercased()).inserted
        }
        if !recentBundleIDs.isEmpty {
            menu.addItem(.separator())
            let applications = item("Приложение", nil, symbol: "app")
            let applicationMenu = makeMenu(title: "Приложение")
            for bundleID in recentBundleIDs.prefix(12) {
                let metadata = AppMetadataStore.shared.metadata(for: bundleID)
                let application = item(
                    MenuTitleFormatter.format(metadata.name, limit: 48), #selector(insertSearchFilter(_:)))
                application.representedObject = "app:\(bundleID)"
                application.toolTip = bundleID
                applicationMenu.addItem(application)
            }
            applications.submenu = applicationMenu
            menu.addItem(applications)
        }
        return menu
    }

    @objc private func insertSearchFilter(_ sender: NSMenuItem) {
        guard activeMenuKind == .history,
              let searchField = activeSearchField,
              let token = sender.representedObject as? String else { return }
        let current = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = MenuSearchRequest.replacingFilter(in: current, with: token)
        searchField.stringValue = query
        searchChanged(query)
        searchField.window?.makeFirstResponder(searchField)
        searchField.currentEditor()?.moveToEndOfDocument(nil)
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
                Self.appendStandardFooter(to: menu, target: self)
            }
            return
        }

        // Enter, Command-1 and destructive shortcuts must not act on results
        // belonging to the previous query during the debounce/database work.
        visibleKeyboardEntries = []
        removeDynamicItems(from: menu)
        menu.addItem(NSMenuItem(title: "Поиск…", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        Self.appendStandardFooter(to: menu, target: self)

        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  generation == self.searchGeneration,
                  self.activeMenu != nil else { return }
            self.searchWorkItem = MenuSearchWork.enqueue(on: self.dataQueue) { [weak self] in
                guard let self else { return }
                do {
                    let request = MenuSearchRequest(query, snippetsOnly: kind == .snippets)
                    let clips = try request.history.map {
                        try Storage.shared.searchSummaries(query: $0, limit: MenuSearchPage<Int>.limit + 1)
                    } ?? []
                    let snippets = try request.snippetTerms.map {
                        try Storage.shared.snippetSummaries(search: $0, pinnedOnly: false, limit: MenuSearchPage<Int>.limit + 1)
                    } ?? []
                    DispatchQueue.main.async {
                        guard generation == self.searchGeneration,
                              let menu = self.activeMenu else { return }
                        self.showSearchResults(
                            clips: clips,
                            snippets: snippets,
                            query: request.snippetTerms ?? "",
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
                        menu.addItem(.separator())
                        Self.appendStandardFooter(to: menu, target: self)
                    }
                }
            }
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50), execute: workItem)
    }

    private func showSearchResults(
        clips: [ClipSummary],
        snippets: [SnippetSummary],
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
        let page = MenuSearchPage(results)
        results = page.entries
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

        if page.hasMore {
            menu.addItem(NSMenuItem(title: "Есть ещё результаты — уточните поиск", action: nil, keyEquivalent: ""))
        }
        if !results.isEmpty || undoDeletion != nil {
            menu.addItem(firstResultActionsItem())
        }
        menu.addItem(.separator())
        if kind == .history {
            menu.addItem(utilityMenuItem())
        }
        menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
        Self.appendStandardFooter(to: menu, target: self)
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
        let capturedTargetPID = targetPID
        activeMenu?.cancelTracking()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch selected {
            case .clip(let clip):
                let sender = NSMenuItem()
                sender.representedObject = NSNumber(value: clip.id)
                self.pasteClip(sender, forcedModifiers: modifiers, destinationPID: capturedTargetPID)
            case .snippet(let snippet):
                guard let id = snippet.id else { return }
                let sender = NSMenuItem()
                sender.representedObject = NSNumber(value: id)
                self.pasteSnippet(sender, forcedModifiers: modifiers, destinationPID: capturedTargetPID)
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
                submenu.addItem(item(
                    "Редактировать сниппет…", #selector(previewFirstResult),
                    symbol: "pencil", keyEquivalent: "e", modifiers: [.command]
                ))
                submenu.addItem(.separator())
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
        guard let entry = visibleKeyboardEntries.first else { return }
        activeMenu?.cancelTracking()
        DispatchQueue.main.async {
            switch entry {
            case .clip(let clip):
                HistoryItemInspectorWindowController.shared.show(clipID: clip.id)
            case .snippet(let snippet):
                guard let id = snippet.id else { return }
                SnippetsEditorWindowController.shared.show(snippetID: id)
            }
        }
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
                guard let textItem = try Storage.shared.fetchOCRTextItem(id: summary.id) else {
                    DispatchQueue.main.async { self?.showFeedback("Распознанного текста нет") }
                    return
                }
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

    /// Keeps low-frequency controls one level below the history itself. The
    /// root stays short and ClipMenu-like while every action remains reachable
    /// from one clearly named native submenu.
    private func utilityMenuItem() -> NSMenuItem {
        let root = item("Управление", nil, symbol: "slider.horizontal.3")
        let submenu = makeMenu(title: "Управление")
        appendSequentialPasteControls(to: submenu)
        submenu.addItem(layoutMenuItem())
        submenu.addItem(.separator())
        addCaptureControls(to: submenu)
        submenu.addItem(historyCleanupMenuItem())
        submenu.addItem(.separator())
        submenu.addItem(item(
            "Проверить обновления…",
            #selector(checkUpdates),
            symbol: "arrow.triangle.2.circlepath"
        ))
        root.submenu = submenu
        return root
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
        let sequenceTargetPID = captureTargetApplication()?.processIdentifier
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
                try Storage.shared.saveClipAsSnippet(id: summary.id)
                DispatchQueue.main.async { self?.showFeedback("Сохранено в «Без папки»") }
            } catch ClipStorageError.clipNotFound {
                DispatchQueue.main.async { self?.showFeedback("Элемент уже удалён") }
            } catch ClipStorageError.snippetRequiresText {
                DispatchQueue.main.async { self?.showFeedback("Сниппет можно создать только из текста") }
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
                    guard Storage.shared.isUndoCurrent(removed.generation) else { return }
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
        guard Storage.shared.isUndoCurrent(removed.generation) else { return }
        activeMenu?.cancelTracking()
        dataQueue.async { [weak self] in
            do {
                switch removed {
                case .clip(let clip):
                    try Storage.shared.restoreClip(clip)
                case .snippet(let snippet):
                    try Storage.shared.restoreSnippet(snippet)
                }
                DispatchQueue.main.async {
                    guard Storage.shared.isUndoCurrent(removed.generation) else { return }
                    self?.showFeedback("Восстановлено")
                }
            } catch {
                DispatchQueue.main.async {
                    guard Storage.shared.isUndoCurrent(removed.generation) else { return }
                    self?.undoDeletion = removed
                    self?.showFeedback("Не удалось восстановить")
                }
            }
        }
    }

    private func snippetFolderItem(title: String, snippets: [SnippetSummary]) -> NSMenuItem {
        let displayTitle = cleanTitle(title)
        let folderItem = item("\(displayTitle) · \(snippets.count)", nil, symbol: "folder")
        folderItem.toolTip = "\(title) · показано: \(snippets.count)"
        let submenu = makeMenu(title: displayTitle)
        for snippet in snippets.sorted(by: SnippetMenuOrder.lessThan) {
            submenu.addItem(snippetMenuItem(snippet, resultIndex: nil, quickKey: nil))
        }
        folderItem.submenu = submenu
        return folderItem
    }

    private func snippetMenuItem(_ snippet: SnippetSummary, resultIndex: Int?, quickKey: String?) -> NSMenuItem {
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
        let folder = snippet.folderTitle
            ?? snapshot.folders.first { $0.id == snippet.folderID }?.title
            ?? (snippet.folderID == nil ? "Без папки" : "Папка")
        entry.toolTip = "\(folder) › \(snippet.title)\n"
            + snippet.contentPreview + (snippet.contentIsTruncated ? "…" : "")
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
        let remember = item(
            "Запоминать раскладку приложений",
            #selector(toggleApplicationLayoutMemory),
            symbol: "app.badge.checkmark"
        )
        remember.state = Settings.rememberLayoutPerApplication ? .on : .off
        submenu.addItem(remember)
        if let bundleID = targetBundleID,
           ApplicationLayoutMemoryPolicy.isEligible(
               bundleID: bundleID,
               ownBundleID: Bundle.main.bundleIdentifier,
               userExcluded: Set(Settings.layoutExcludedApps)
           ), KeyboardLayoutService.shared.currentSelectableSourceID() != nil {
            let appName = AppMetadataStore.shared.metadata(for: bundleID).name
            let fixed = item(
                "Закрепить текущую для \(MenuTitleFormatter.format(appName, limit: 32))",
                #selector(toggleFixedLayoutForTargetApplication),
                symbol: "pin"
            )
            fixed.state = Settings.fixedLayoutSource(for: bundleID) == nil ? .off : .on
            submenu.addItem(fixed)
        }
        submenu.addItem(.separator())
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
        submenu.addItem(item("⌃↩ — исправить выбранную запись истории и вставить", nil, symbol: "info.circle"))
        root.submenu = submenu
        return root
    }

    private func historyCleanupMenuItem() -> NSMenuItem {
        let root = item("Очистить историю", nil, symbol: "trash")
        let submenu = makeMenu(title: "Очистить историю")
        submenu.addItem(item("За последний час…", #selector(clearHistoryLastHour), symbol: "clock"))
        submenu.addItem(item("За сегодня…", #selector(clearHistoryToday), symbol: "calendar"))
        submenu.addItem(.separator())
        submenu.addItem(item("Всю незакреплённую…", #selector(clearHistory), symbol: "trash"))
        root.submenu = submenu
        return root
    }

    private func addCaptureControls(to menu: NSMenu) {
        if ClipboardAccess.current == .denied {
            menu.addItem(item("Запись истории недоступна", nil, symbol: "exclamationmark.shield"))
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
            let appendTitle = Settings.appendNextCopy
                ? "Следующий текст объединится с предыдущим"
                : "Объединить следующий текст с предыдущим"
            let append = item(appendTitle, #selector(appendNextCopy), symbol: "doc.on.doc")
            append.state = Settings.appendNextCopy ? .on : .off
            menu.addItem(append)
            let pause = item("Приостановить запись", nil, symbol: "pause.fill")
            let pauseMenu = makeMenu(title: "Приостановить запись")
            pauseMenu.addItem(item("На 15 минут", #selector(pauseForFifteenMinutes), symbol: "timer"))
            pauseMenu.addItem(item("До возобновления", #selector(pauseIndefinitely), symbol: "pause.fill"))
            pause.submenu = pauseMenu
            menu.addItem(pause)
        }
        guard let bundleID = targetBundleID else { return }
        let appName = MenuTitleFormatter.format(
            AppMetadataStore.shared.metadata(for: bundleID).name,
            limit: 32
        )
        let isProtected = SensitiveApplicationPolicy.protects(bundleID)
        let isExcluded = Settings.excludedApps.contains {
            $0.caseInsensitiveCompare(bundleID) == .orderedSame
        }
        let title: String
        if isProtected {
            title = "Не сохранять из \(appName) — всегда"
        } else if isExcluded {
            title = "Снова сохранять из \(appName)"
        } else {
            title = "Не сохранять из \(appName)"
        }
        let applicationRule = item(
            title,
            isProtected ? nil : #selector(toggleCaptureForTargetApplication(_:)),
            symbol: isProtected ? "lock.shield" : "app.badge"
        )
        applicationRule.state = isExcluded ? .on : .off
        applicationRule.representedObject = bundleID
        menu.addItem(applicationRule)
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

    private func captureTargetApplication() -> (processIdentifier: pid_t, bundleIdentifier: String)? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = application.bundleIdentifier,
              bundleIdentifier != Bundle.main.bundleIdentifier,
              !application.isTerminated else { return nil }
        return (application.processIdentifier, bundleIdentifier)
    }

    @objc private func pasteClip(_ sender: NSMenuItem) {
        pasteClip(sender, forcedModifiers: nil, destinationPID: targetPID)
    }

    @objc private func quickPasteClip(_ sender: NSMenuItem) {
        pasteClip(sender, forcedModifiers: NSEvent.modifierFlags.subtracting(.command), destinationPID: targetPID)
    }

    private func pasteClip(_ sender: NSMenuItem, forcedModifiers: NSEvent.ModifierFlags?, destinationPID: pid_t?) {
        guard let id = (sender.representedObject as? NSNumber)?.int64Value else { return }
        let capturedTargetPID = destinationPID
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
        pasteSnippet(sender, forcedModifiers: nil, destinationPID: targetPID)
    }

    @objc private func quickPasteSnippet(_ sender: NSMenuItem) {
        pasteSnippet(sender, forcedModifiers: NSEvent.modifierFlags.subtracting(.command), destinationPID: targetPID)
    }

    private func pasteSnippet(_ sender: NSMenuItem, forcedModifiers: NSEvent.ModifierFlags?, destinationPID: pid_t?) {
        guard let id = (sender.representedObject as? NSNumber)?.int64Value else { return }
        let capturedTargetPID = destinationPID
        let copyOnly = (forcedModifiers ?? NSEvent.modifierFlags).contains(.command)
        let clipboard = NSPasteboard.general.string(forType: .string)
        dataQueue.async { [weak self] in
            do {
                guard var snippet = try Storage.shared.fetchSnippet(id: id) else {
                    DispatchQueue.main.async { self?.showFeedback("Сниппет уже удалён") }
                    return
                }
                snippet.content = try SnippetRenderer.render(snippet.content, clipboard: clipboard)
                try? Storage.shared.markSnippetUsed(id: id)
                DispatchQueue.main.async {
                    PasteService.paste(
                        snippet: snippet,
                        targetPID: capturedTargetPID,
                        copyOnly: copyOnly
                    ) { [weak self] result in
                        self?.handlePasteResult(result)
                    }
                }
            } catch is SnippetRenderingError {
                DispatchQueue.main.async { self?.showFeedback("Сниппет после подстановок превышает 2 МБ") }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось открыть сниппет") }
            }
        }
    }

    private func handlePasteResult(_ result: PasteResult) {
        // Completion can arrive after another menu has captured a new target.
        // Never clear or replace that newer menu's destination here.
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
        } else if Settings.appendNextCopy {
            symbolName = "doc.on.doc"
        } else {
            symbolName = "doc.on.clipboard"
        }
        if let image = symbol(symbolName, description: "NeClip") {
            button.image = image
            button.title = ""
        } else {
            button.title = Settings.isCapturePaused
                ? "Ⅱ"
                : (Settings.ignoreNextCopy ? "→" : (Settings.appendNextCopy ? "+" : "⧉"))
        }
        if ClipboardAccess.current == .denied {
            button.toolTip = "NeClip — доступ к буферу запрещён"
        } else {
            if Settings.isCapturePaused {
                button.toolTip = "NeClip — запись приостановлена"
            } else if Settings.ignoreNextCopy {
                button.toolTip = "NeClip — следующее копирование будет пропущено"
            } else if Settings.appendNextCopy {
                button.toolTip = "NeClip — следующий текст объединится с предыдущим"
            } else {
                let history = HotKeyCoordinator.shared.shortcut(for: .history).displayString
                let snippets = HotKeyCoordinator.shared.shortcut(for: .snippets).displayString
                button.toolTip = "NeClip — история \(history) · папки сниппетов \(snippets) или правый клик"
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

    @objc private func captureDidAppend() {
        showFeedback("текст объединён с предыдущим")
    }

    @objc private func toggleCaptureForTargetApplication(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String,
              !SensitiveApplicationPolicy.protects(bundleID) else { return }
        var excluded = Settings.excludedApps
        if excluded.contains(where: { $0.caseInsensitiveCompare(bundleID) == .orderedSame }) {
            excluded.removeAll { $0.caseInsensitiveCompare(bundleID) == .orderedSame }
            Settings.excludedApps = excluded
            showFeedback("копии из приложения снова сохраняются")
        } else {
            excluded.append(bundleID)
            Settings.excludedApps = excluded
            showFeedback("приложение исключено из истории")
        }
    }

    @objc private func ignoreNextCopy() {
        Settings.ignoreNextCopy.toggle()
        refreshIcon()
        showFeedback(Settings.ignoreNextCopy ? "следующее копирование не сохранится" : "пропуск отменён")
    }

    @objc private func appendNextCopy() {
        Settings.appendNextCopy.toggle()
        refreshIcon()
        showFeedback(Settings.appendNextCopy ? "следующий текст объединится с предыдущим" : "объединение отменено")
    }

    @objc private func toggleApplicationLayoutMemory() {
        Settings.rememberLayoutPerApplication.toggle()
        showFeedback(
            Settings.rememberLayoutPerApplication
                ? "раскладка приложений запоминается"
                : "запоминание раскладки выключено"
        )
    }

    @objc private func toggleFixedLayoutForTargetApplication() {
        guard let bundleID = targetBundleID else { return }
        let appName = AppMetadataStore.shared.metadata(for: bundleID).name
        if Settings.fixedLayoutSource(for: bundleID) != nil {
            Settings.setFixedLayoutSource(nil, for: bundleID)
            showFeedback("закрепление для \(appName) снято")
        } else if let sourceID = KeyboardLayoutService.shared.currentSelectableSourceID() {
            Settings.setFixedLayoutSource(sourceID, for: bundleID)
            showFeedback("текущая раскладка закреплена для \(appName)")
        }
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
        showFeedback(Settings.captureResumeFailureMessage ?? "запись возобновлена")
    }

    @objc private func clearHistory() {
        confirmHistoryCleanup(.all)
    }

    @objc private func clearHistoryLastHour() {
        confirmHistoryCleanup(.lastHour)
    }

    @objc private func clearHistoryToday() {
        confirmHistoryCleanup(.today)
    }

    private func confirmHistoryCleanup(_ scope: HistoryCleanupWindow) {
        let alert = NSAlert()
        alert.messageText = "Удалить \(scope.title)?"
        alert.informativeText = "Закреплённые элементы и сниппеты останутся."
        alert.addButton(withTitle: "Удалить")
        alert.addButton(withTitle: "Отмена")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task { @MainActor [weak self] in
            do {
                let message = try await HistoryCleanupCoordinator.shared.run {
                    let removed = try Storage.shared.clearHistory(
                        includePinned: false,
                        createdAfter: scope.cutoff()
                    )
                    let result = removed == 0 ? "нечего удалять" : "удалено элементов: \(removed)"
                    if scope == .all {
                        do { try Storage.shared.vacuum() }
                        catch { return "\(result); освобождение места в файле базы отложено" }
                    }
                    return result
                }
                self?.showFeedback(message)
            } catch {
                self?.showFeedback("не удалось очистить историю: \(error.localizedDescription)")
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
        showFeedback("проверяем обновления…")
        UpdateChecker.check()
    }

    /// NSMenu actions are explicitly targeted at this controller. Forwarding
    /// `NSApplication.terminate(_:)` with that target leaves AppKit without a
    /// responder and disables the item, so quit uses a real local action.
    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}

extension StatusBarController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        searchChanged(field.stringValue)
    }
}

@MainActor
final class MenuSearchField: NSSearchField {
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
        if handleCommand(event) { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // AppKit may route Command combinations before keyDown. Only the
        // focused search (or its field editor) owns these menu commands.
        if event.modifierFlags.contains(.command), let window,
           window.firstResponder === self || (currentEditor() != nil && window.firstResponder === currentEditor()),
           handleCommand(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    @discardableResult
    func handleCommand(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
        // Match the same physical positions as configurable global shortcuts.
        // Translated characters would turn ⌘E into «⌘у» on a Russian layout.
        let character = ShortcutDescriptor(keyCode: UInt32(event.keyCode), modifiers: []).keyEquivalent ?? ""
        if MenuSearchKeyPolicy.shouldPreviewOnSpace(
            keyCode: event.keyCode,
            modifiers: modifiers,
            searchText: stringValue,
            isRepeat: event.isARepeat
        ) {
            onPreviewFirst?()
            return true
        }
        if modifiers.contains(.command), let number = Int(character), (1...9).contains(number) {
            onQuickSelect?(number - 1, modifiers)
            return true
        }
        if modifiers == .command, !event.isARepeat {
            switch character.lowercased() {
            case "p":
                onTogglePinFirst?()
                return true
            case "s":
                onSaveFirstAsSnippet?()
                return true
            case "z":
                if MenuSearchKeyPolicy.allowsHistoryMutation(searchText: stringValue) {
                    onUndo?()
                    return true
                }
            case "e":
                onPreviewFirst?()
                return true
            case "o":
                onOpenFirst?()
                return true
            default:
                if event.keyCode == 51, MenuSearchKeyPolicy.allowsHistoryMutation(searchText: stringValue) {
                    onDeleteFirst?()
                    return true
                }
            }
        }
        if event.keyCode == 36 || event.keyCode == 76 {
            onSubmit?(modifiers)
            return true
        }
        if MenuSearchKeyPolicy.shouldNavigateToMenu(keyCode: event.keyCode, modifiers: modifiers) {
            onNavigateToMenu?()
            return true
        }
        return false
    }
}

enum MenuSearchKeyPolicy {
    static func allowsHistoryMutation(searchText: String) -> Bool { searchText.isEmpty }

    static func shouldNavigateToMenu(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        modifiers.isEmpty && (keyCode == 125 || keyCode == 126)
    }

    static func shouldPreviewOnSpace(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        searchText: String,
        isRepeat: Bool
    ) -> Bool {
        keyCode == 49 && modifiers.isEmpty && searchText.isEmpty && !isRepeat
    }
}
