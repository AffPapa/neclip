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

    private struct MenuSnapshot {
        let clips: [ClipSummary]
        let folders: [SnippetFolder]
        let snippets: [Snippet]
    }

    private let statusItem: NSStatusItem
    private let dataQueue = DispatchQueue(label: "org.affpapa.neclip.menu-data", qos: .userInitiated)
    private var snapshot = MenuSnapshot(clips: [], folders: [], snippets: [])
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
    private var visibleKeyboardEntries: [SearchEntry] = []

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemPressed(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "NeClip — ⌘⇧V"
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

    /// Global ⌘⇧V: show the native menu at the pointer, like ClipMenu/Clipy.
    func showHistory() {
        show(.history, anchoredToStatusItem: false)
    }

    /// Global ⌘⇧B: open the snippet folders directly.
    func showSnippets() {
        show(.snippets, anchoredToStatusItem: false)
    }

    func refreshIfVisible() {
        refreshSnapshot()
        refreshIcon()
    }

    func refreshAuthorizationState() {
        refreshIcon()
    }

    func showLayoutFeedback(_ message: String) {
        showFeedback(message)
        Task { @MainActor in LayoutFeedbackHUD.shared.show(message) }
    }

    @objc private func storageDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshSnapshot()
        }
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
        refreshGeneration += 1
        let generation = refreshGeneration
        dataQueue.async { [weak self] in
            do {
                let pinned = try Storage.shared.summaries(
                    limit: 20,
                    search: nil,
                    pinnedOnly: true
                )
                let recent = try Storage.shared.summaries(
                    limit: 40,
                    search: nil,
                    pinnedOnly: false,
                    unpinnedOnly: true
                )
                let folders = try Storage.shared.snippetFolders()
                let snippets = try Storage.shared.allSnippets(search: nil, pinnedOnly: false)
                let loaded = MenuSnapshot(clips: pinned + recent, folders: folders, snippets: snippets)
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

    private func buildHistoryMenu() -> NSMenu {
        let menu = NSMenu(title: "NeClip")
        menu.addItem(makeSearchItem(placeholder: "Поиск в истории и сниппетах…"))
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

        let pinned = Array(snapshot.clips.filter(\.isPinned).prefix(20))
        if !pinned.isEmpty {
            let pinnedItem = item("Закреплённые", nil, symbol: "pin.fill")
            let pinnedMenu = NSMenu(title: "Закреплённые")
            for (index, clip) in pinned.enumerated() {
                pinnedMenu.addItem(clipMenuItem(clip, absoluteIndex: index, quickKey: nil, showNumber: false))
            }
            pinnedItem.submenu = pinnedMenu
            menu.addItem(pinnedItem)
            menu.addItem(.separator())
        }

        menu.addItem(.sectionHeader(title: "История"))
        let history = Array(snapshot.clips.filter { !$0.isPinned }.prefix(40))
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
            for start in stride(from: 10, to: history.count, by: 10) {
                let end = min(start + 10, history.count)
                let rangeItem = item("\(start + 1)–\(end)", nil, symbol: "folder")
                let submenu = NSMenu(title: "\(start + 1)–\(end)")
                for index in start..<end {
                    submenu.addItem(clipMenuItem(history[index], absoluteIndex: index, quickKey: nil, showNumber: true))
                }
                rangeItem.submenu = submenu
                menu.addItem(rangeItem)
            }
        }
        menu.addItem(.separator())

        let snippetsItem = item("Сниппеты", nil, symbol: "scissors")
        snippetsItem.submenu = buildSnippetsMenu(asRoot: false)
        menu.addItem(snippetsItem)

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
        let menu = NSMenu(title: "Сниппеты")
        if asRoot {
            menu.addItem(makeSearchItem(placeholder: "Поиск сниппетов…"))
            menu.addItem(.separator())
        }
        appendSnippetContents(to: menu, showHeader: asRoot)
        return menu
    }

    private func appendSnippetContents(to menu: NSMenu, showHeader: Bool) {
        if showHeader {
            let quickSnippets = Array(snapshot.snippets.prefix(9))
            visibleKeyboardEntries = quickSnippets.map(SearchEntry.snippet)
            menu.addItem(.sectionHeader(title: "Быстрые"))
            if quickSnippets.isEmpty {
                menu.addItem(NSMenuItem(title: "Сниппетов пока нет", action: nil, keyEquivalent: ""))
                menu.addItem(.separator())
                menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
                return
            }
            for (index, snippet) in quickSnippets.enumerated() {
                menu.addItem(snippetMenuItem(snippet, resultIndex: index, quickKey: quickKey(for: index)))
            }
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
                    let clips = kind == .history
                        ? try Storage.shared.summaries(limit: 20, search: query, pinnedOnly: false)
                        : []
                    let snippets = try Storage.shared.allSnippets(search: query, pinnedOnly: false)
                    DispatchQueue.main.async {
                        guard generation == self.searchGeneration,
                              let menu = self.activeMenu else { return }
                        self.showSearchResults(clips: clips, snippets: snippets, query: query, kind: kind, in: menu)
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
        let remainingSnippets = snippets.filter { snippet in
            !exactSnippets.contains(where: { $0.id == snippet.id })
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

        menu.addItem(.separator())
        if kind == .history {
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

    private func snippetFolderItem(title: String, snippets: [Snippet]) -> NSMenuItem {
        let folderItem = item(title, nil, symbol: "folder")
        let submenu = NSMenu(title: title)
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
            symbol: symbolName(for: clip.kind),
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
        let submenu = NSMenu(title: "Раскладка")
        let automatic = item(
            "Автоматически исправлять (бета)",
            #selector(toggleAutomaticLayoutCorrection),
            symbol: "wand.and.stars"
        )
        automatic.state = Settings.automaticLayoutCorrection ? .on : .off
        submenu.addItem(automatic)
        submenu.addItem(item(
            "Исправить выделение или последнее слово",
            #selector(correctFocusedLayout),
            symbol: "text.cursor",
            keyEquivalent: "l",
            modifiers: [.option, .shift]
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
            let pauseMenu = NSMenu(title: "Приостановить запись")
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

    private func quickKey(for index: Int) -> String? {
        guard (0..<9).contains(index) else { return nil }
        return String(index + 1)
    }

    private func cleanTitle(_ value: String) -> String {
        let singleLine = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard singleLine.count > 62 else { return singleLine }
        return String(singleLine.prefix(61)) + "…"
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
        let plainText = modifiers.contains(.option) || modifiers.contains(.shift) || correctLayout
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
            Settings.automaticLayoutCorrection = false
            showFeedback("Автоисправление выключено")
            return
        }
        PreferencesWindowController.shared.show()
        showLayoutFeedback("Включите автоисправление в разделе «Раскладка»")
    }

    @objc private func correctFocusedLayout() {
        NotificationCenter.default.post(name: .neClipManualLayoutCorrectionRequested, object: nil)
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
            button.toolTip = Settings.isCapturePaused
                ? "NeClip — запись приостановлена"
                : (Settings.ignoreNextCopy ? "NeClip — следующее копирование будет пропущено" : "NeClip — ⌘⇧V")
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
                    self?.refreshSnapshot()
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
