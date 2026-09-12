import AppKit

private final class ClipSnippetTarget: NSObject {
    let clipID: Int64
    let folderID: Int64?

    init(clipID: Int64, folderID: Int64?) {
        self.clipID = clipID
        self.folderID = folderID
    }
}

/// The default NeClip interface is a classic native menu: recent history is
/// visible immediately, older entries are grouped by tens, and the dedicated
/// snippets shortcut opens the same folders without the history.
@MainActor
final class StatusBarController: NSObject {
    private enum MenuKind: Equatable {
        case history
        case snippets
    }

    private enum HistoryCleanupWindow: Equatable {
        case lastHour
        case today
        case all

        var title: String {
            switch self {
            case .lastHour: "историю за последний час"
            case .today: "сегодняшнюю историю"
            case .all: "всю историю"
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

    private struct MenuSnapshot: Sendable {
        let clips: [ClipSummary]
        let folders: [SnippetFolder]
        let snippets: [SnippetSummary]
        let hasMoreHistory: Bool
        let hasMoreSnippets: Bool
    }

    private let statusItem: NSStatusItem
    private let dataQueue = DispatchQueue(label: "org.affpapa.neclip.menu-data", qos: .userInitiated)
    private var snapshot = MenuSnapshot(
        clips: [],
        folders: [],
        snippets: [],
        hasMoreHistory: false,
        hasMoreSnippets: false
    )
    private var snapshotIsReady = false
    private var refreshState = MenuRefreshState()
    private var pendingPresentation: (kind: MenuKind, anchoredToStatusItem: Bool)?
    private var targetPID: pid_t?
    private var targetBundleID: String?
    private var feedbackWorkItem: DispatchWorkItem?
    private var transientStatus: String?
    private weak var activeMenu: NSMenu?
    private var snapshotRefreshWorkItem: DispatchWorkItem?
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
        let domain = StorageChangeDomain.from(notification)
        refreshState.invalidate(domain)
        if domain == .all {
            activeMenu?.cancelTracking()
            snapshot = MenuSnapshot(clips: [], folders: [], snippets: [],
                                    hasMoreHistory: false, hasMoreSnippets: false)
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
        // An unsuccessful read must be retried on the next explicit open,
        // rather than leaving an empty/stale menu until another copy occurs.
        guard snapshotIsReady, refreshState.domains.isEmpty else {
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
        let menu = kind == .history ? buildHistoryMenu() : buildSnippetsMenu()
        MenuAppearance.applyEffectiveAppearance(to: menu)
        activeMenu = menu
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
    }

    private func refreshSnapshot() {
        snapshotRefreshWorkItem?.cancel()
        snapshotRefreshWorkItem = nil
        let generation = refreshState.begin()
        let domains = refreshState.domains
        let previous = snapshot
        dataQueue.async { [weak self] in
            do {
                var clips = previous.clips
                var hasMoreHistory = previous.hasMoreHistory
                if domains.contains(.clips) {
                    let recent = try Storage.shared.summaries(limit: 101)
                    clips = Array(recent.prefix(100))
                    hasMoreHistory = recent.count > 100
                }
                let snippetSnapshot = try domains.contains(.snippets)
                    ? Storage.shared.menuSnippetSnapshot() : nil
                let loaded = MenuSnapshot(
                    clips: clips,
                    folders: snippetSnapshot?.folders ?? previous.folders,
                    snippets: snippetSnapshot?.snippets ?? previous.snippets,
                    hasMoreHistory: hasMoreHistory,
                    hasMoreSnippets: snippetSnapshot?.hasMore ?? previous.hasMoreSnippets
                )
                DispatchQueue.main.async {
                    guard let self, self.refreshState.accept(generation) else { return }
                    self.snapshot = loaded
                    self.snapshotIsReady = true
                    if let pending = self.pendingPresentation {
                        self.pendingPresentation = nil
                        self.present(pending.kind, anchoredToStatusItem: pending.anchoredToStatusItem)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self, generation == self.refreshState.generation else { return }
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

    /// Data changes often arrive as a short notification burst.
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

        if RuntimeIdentity.isIsolatedPreview {
            menu.addItem(NSMenuItem(title: "Тестовая копия · отдельная история", action: nil, keyEquivalent: ""))
        }
        menu.addItem(item(
            "Поиск истории…",
            #selector(openHistorySearch),
            symbol: "magnifyingglass",
            keyEquivalent: "f",
            modifiers: [.command]
        ))
        menu.addItem(.separator())
        menu.addItem(.sectionHeader(title: "Недавние"))
        // refreshSnapshot() already bounds the snapshot to 100 rows. Keep the
        // existing storage and first page as slices instead of copying them
        // every time the menu opens.
        let history = snapshot.clips
        let firstPage = history.prefix(10)
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
            menu.addItem(item("Показаны 100 последних копирований", nil))
        }
        menu.addItem(.separator())

        menu.addItem(.sectionHeader(title: "Сниппеты"))
        appendSnippetFolders(to: menu)
        menu.addItem(.separator())

        menu.addItem(utilityMenuItem())
        menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
        Self.appendStandardFooter(to: menu, target: self)
    }

    private func buildSnippetsMenu() -> NSMenu {
        let menu = makeMenu(title: "Сниппеты")
        appendHotKeyWarnings(to: menu)
        menu.addItem(.sectionHeader(title: "Папки"))
        appendSnippetFolders(to: menu)
        menu.addItem(.separator())
        menu.addItem(item("Редактор сниппетов…", #selector(openSnippetsEditor), symbol: "pencil"))
        Self.appendStandardFooter(to: menu, target: self)
        return menu
    }

    /// Shared by initial, loading, empty, error and result states. Explicit
    /// targets keep Quit enabled in a menu-bar-only application.
    static func appendStandardFooter(to menu: NSMenu, target: AnyObject) {
        let shortcut = HotKeyCoordinator.shared.shortcut(for: .screenshot)
        let screenshot = NSMenuItem(title: "Снимок области…", action: #selector(takeScreenshot),
                                    keyEquivalent: shortcut.keyEquivalent ?? "")
        screenshot.target = target
        screenshot.keyEquivalentModifierMask = shortcut.nsEventModifiers
        screenshot.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)
        menu.addItem(screenshot)
        let fullScreenShortcut = HotKeyCoordinator.shared.shortcut(for: .fullScreenScreenshot)
        let fullScreen = NSMenuItem(title: "Снимок всего экрана", action: #selector(takeFullScreenScreenshot),
                                    keyEquivalent: fullScreenShortcut.keyEquivalent ?? "")
        fullScreen.target = target
        fullScreen.keyEquivalentModifierMask = fullScreenShortcut.nsEventModifiers
        fullScreen.image = NSImage(systemSymbolName: "rectangle.inset.filled", accessibilityDescription: nil)
        menu.addItem(fullScreen)
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

    @objc private func takeScreenshot() {
        activeMenu?.cancelTracking()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .neClipScreenshotRequested, object: nil)
        }
    }

    @objc private func takeFullScreenScreenshot() {
        activeMenu?.cancelTracking()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .neClipFullScreenScreenshotRequested, object: nil)
        }
    }

    private func appendSnippetFolders(to menu: NSMenu) {
        var addedSnippetGroup = false
        let grouped = Dictionary(grouping: snapshot.snippets, by: \.folderID)
        // Folder IDs are stable database keys; resolve titles once per menu,
        // not once per snippet row.
        let folderTitles = Dictionary(
            uniqueKeysWithValues: snapshot.folders.compactMap { folder in
                folder.id.map { ($0, folder.title) }
            }
        )
        for folder in snapshot.folders {
            guard let folderID = folder.id, let snippets = grouped[folderID], !snippets.isEmpty else { continue }
            menu.addItem(snippetFolderItem(title: folder.title, snippets: snippets, folderTitles: folderTitles))
            addedSnippetGroup = true
        }

        let knownFolderIDs = Set(snapshot.folders.compactMap(\.id))
        let unfiled = snapshot.snippets.filter { snippet in
            guard let folderID = snippet.folderID else { return true }
            return !knownFolderIDs.contains(folderID)
        }
        if !unfiled.isEmpty {
            menu.addItem(snippetFolderItem(title: "Без папки", snippets: unfiled, folderTitles: folderTitles))
            addedSnippetGroup = true
        }

        if !addedSnippetGroup {
            menu.addItem(NSMenuItem(title: "Сниппетов пока нет", action: nil, keyEquivalent: ""))
        }
        if snapshot.hasMoreSnippets {
            menu.addItem(item("Остальные сниппеты доступны в редакторе", nil))
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
    /// root stays a single, chronological feed; rare actions remain reachable
    /// without competing with history or snippets.
    private func utilityMenuItem() -> NSMenuItem {
        let root = item("Ещё…", nil, symbol: "ellipsis.circle")
        let submenu = makeMenu(title: "Ещё")
        appendSequentialPasteControls(to: submenu)
        submenu.addItem(layoutMenuItem())
        submenu.addItem(.separator())
        submenu.addItem(captureStatusMenuItem())
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

    private func snippetFolderItem(
        title: String,
        snippets: [SnippetSummary],
        folderTitles: [Int64: String]
    ) -> NSMenuItem {
        let displayTitle = cleanTitle(title)
        let folderItem = item("\(displayTitle) · \(snippets.count)", nil, symbol: "folder")
        folderItem.toolTip = "\(title) · показано: \(snippets.count)"
        let submenu = makeMenu(title: displayTitle)
        // The bounded SQL snapshot already orders each folder by sortIndex/ID;
        // grouping preserves that order, including the unfiled fallback.
        for snippet in snippets {
            submenu.addItem(snippetMenuItem(snippet, folderTitles: folderTitles))
        }
        folderItem.submenu = submenu
        return folderItem
    }

    private func snippetMenuItem(
        _ snippet: SnippetSummary,
        folderTitles: [Int64: String],
        absoluteIndex: Int? = nil,
        quickKey: String? = nil,
        showNumber: Bool = false
    ) -> NSMenuItem {
        let prefix = showNumber ? "\((absoluteIndex ?? 0) + 1). " : ""
        let entry = item(
            prefix + cleanTitle(snippet.title),
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
            ?? snippet.folderID.flatMap { folderTitles[$0] }
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
        entry.toolTip = [clip.text,
                         clip.kind == .text ? "⇧ — без оформления · ⌃ — исправить раскладку" : nil]
            .compactMap { $0 }.joined(separator: "\n")
        entry.submenu = clipActionsMenu(for: clip)
        return entry
    }

    /// Keeps the top-level history chronological while exposing explicit
    /// actions in a submenu. The ordinary item still owns the original paste
    /// action; the submenu is the discoverable path for keyboard modifiers,
    /// links and history-to-snippet conversion.
    private func clipActionsMenu(for clip: ClipSummary) -> NSMenu {
        let menu = makeMenu(title: "Действия")
        menu.addItem(item(
            "Вставить",
            #selector(pasteClipOriginal(_:)),
            symbol: "arrow.down.doc",
            keyEquivalent: "↩",
            modifiers: []
        ))
        menu.items.last?.representedObject = NSNumber(value: clip.id)
        menu.addItem(item(
            "Вставить как обычный текст",
            #selector(pasteClipPlain(_:)),
            symbol: "text.alignleft"
        ))
        menu.items.last?.representedObject = NSNumber(value: clip.id)
        menu.addItem(item(
            "Только скопировать",
            #selector(copyClipOnly(_:)),
            symbol: "doc.on.doc"
        ))
        menu.items.last?.representedObject = NSNumber(value: clip.id)

        if HistoryItemActionResolver.openTarget(for: ClipItem(
            id: clip.id, kind: clip.kind, title: clip.title, text: clip.text,
            appBundleID: clip.appBundleID, createdAt: clip.createdAt, isPinned: clip.isPinned
        )) != nil {
            menu.addItem(item("Открыть ссылку или файл", #selector(openClipTarget(_:)), symbol: "arrow.up.right.square"))
            menu.items.last?.representedObject = NSNumber(value: clip.id)
        }

        if clip.kind == .text {
            let save = item("Сохранить в сниппеты…", nil, symbol: "text.badge.plus")
            let folders = makeMenu(title: "Сохранить в сниппеты")
            let unfiled = item("Без папки", #selector(saveClipAsSnippet(_:)), symbol: "tray")
            unfiled.representedObject = ClipSnippetTarget(clipID: clip.id, folderID: nil)
            folders.addItem(unfiled)
            if !snapshot.folders.isEmpty {
                folders.addItem(.separator())
                for folder in snapshot.folders {
                    guard let folderID = folder.id else { continue }
                    let folderItem = item(folder.title, #selector(saveClipAsSnippet(_:)), symbol: "folder")
                    folderItem.representedObject = ClipSnippetTarget(clipID: clip.id, folderID: folderID)
                    folders.addItem(folderItem)
                }
            }
            save.submenu = folders
            menu.addItem(save)
        }
        return menu
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
        submenu.addItem(item("⌃ + щелчок — исправить раскладку при вставке", nil, symbol: "info.circle"))
        root.submenu = submenu
        return root
    }

    private func historyCleanupMenuItem() -> NSMenuItem {
        let root = item("Очистить историю", nil, symbol: "trash")
        let submenu = makeMenu(title: "Очистить историю")
        submenu.addItem(item("За последний час…", #selector(clearHistoryLastHour), symbol: "clock"))
        submenu.addItem(item("За сегодня…", #selector(clearHistoryToday), symbol: "calendar"))
        submenu.addItem(.separator())
        submenu.addItem(item("Всю историю…", #selector(clearHistory), symbol: "trash"))
        root.submenu = submenu
        return root
    }

    private func captureStatusMenuItem() -> NSMenuItem {
        let root = item("Состояние и приватность…", nil, symbol: "checkmark.shield")
        let submenu = makeMenu(title: "Состояние и приватность")

        let historyTitle: String
        switch Settings.capturePauseState {
        case .active: historyTitle = "История: запись включена"
        case .until(let date):
            historyTitle = "История: пауза до \(Self.statusDateFormatter.string(from: date))"
        case .indefinite: historyTitle = "История: запись приостановлена"
        }
        submenu.addItem(item(historyTitle, nil, symbol: Settings.isCapturePaused ? "pause.circle" : "checkmark.circle"))

        let pasteboardTitle: String
        switch ClipboardAccess.current {
        case .unrestricted, .allowed: pasteboardTitle = "Буфер macOS: доступен"
        case .needsChoice: pasteboardTitle = "Буфер macOS: требуется разрешение"
        case .denied: pasteboardTitle = "Буфер macOS: доступ запрещён"
        }
        submenu.addItem(item(pasteboardTitle, nil, symbol: ClipboardAccess.current == .denied ? "exclamationmark.shield" : "doc.on.clipboard"))

        submenu.addItem(item(
            PasteService.isAccessibilityTrusted
                ? "Автовставка: доступна"
                : "Автовставка: только копирование",
            nil,
            symbol: PasteService.isAccessibilityTrusted ? "hand.thumbsup" : "hand.raised"
        ))
        if Settings.ignoreNextCopy {
            submenu.addItem(item("Следующее копирование будет пропущено", nil, symbol: "forward.end"))
        }
        submenu.addItem(.separator())

        if Settings.isCapturePaused {
            submenu.addItem(item("Возобновить запись", #selector(resumeCapture), symbol: "play.fill"))
        } else {
            let pause = item("Приостановить запись", nil, symbol: "pause.fill")
            let pauseMenu = makeMenu(title: "Приостановить запись")
            pauseMenu.addItem(item("На 15 минут", #selector(pauseForFifteenMinutes), symbol: "timer"))
            pauseMenu.addItem(item("До возобновления", #selector(pauseIndefinitely), symbol: "pause.fill"))
            pause.submenu = pauseMenu
            submenu.addItem(pause)
        }
        submenu.addItem(item(
            Settings.ignoreNextCopy ? "Отменить пропуск следующей копии" : "Не сохранять следующее копирование",
            #selector(ignoreNextCopy), symbol: "forward.end"
        ))
        if ClipboardAccess.current == .denied || ClipboardAccess.current == .needsChoice {
            submenu.addItem(item("Настроить доступ к буферу…", #selector(openClipboardPrivacy), symbol: "gearshape"))
        }
        if !PasteService.isAccessibilityTrusted {
            submenu.addItem(item("Разрешить автовставку…", #selector(requestAccessibility), symbol: "hand.raised"))
        }
        submenu.addItem(.separator())
        submenu.addItem(item("Открыть настройки…", #selector(openPreferences), symbol: "gearshape"))
        root.submenu = submenu
        return root
    }

    private static let statusDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

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
        clip.kind == .text && HistoryItemActionResolver.webURL(clip.text ?? clip.title) != nil
            ? "link" : symbolName(for: clip.kind)
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
        pasteClip(sender, forcedModifiers: actionModifiers, destinationPID: targetPID)
    }

    @objc private func pasteClipOriginal(_ sender: NSMenuItem) {
        pasteClip(sender, forcedModifiers: [], destinationPID: targetPID)
    }

    @objc private func pasteClipPlain(_ sender: NSMenuItem) {
        pasteClip(sender, forcedModifiers: [.shift], destinationPID: targetPID)
    }

    @objc private func copyClipOnly(_ sender: NSMenuItem) {
        pasteClip(sender, forcedModifiers: [.command], destinationPID: targetPID)
    }

    @objc private func openClipTarget(_ sender: NSMenuItem) {
        guard let id = (sender.representedObject as? NSNumber)?.int64Value else { return }
        openClipTarget(id: id)
    }

    private func openClipTarget(id: Int64) {
        dataQueue.async { [weak self] in
            do {
                guard let clip = try Storage.shared.fetchClip(id: id),
                      let target = HistoryItemActionResolver.openTarget(for: clip) else {
                    DispatchQueue.main.async { self?.showFeedback("Открывать можно только безопасные ссылки и существующие файлы") }
                    return
                }
                DispatchQueue.main.async {
                    NSWorkspace.shared.open(target)
                }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось открыть элемент") }
            }
        }
    }

    @objc private func saveClipAsSnippet(_ sender: NSMenuItem) {
        guard let target = sender.representedObject as? ClipSnippetTarget else { return }
        saveHistoryClipAsSnippet(id: target.clipID, folderID: target.folderID)
    }

    private func saveHistoryClipAsSnippet(id: Int64, folderID: Int64? = nil) {
        activeMenu?.cancelTracking()
        let clipID = id
        dataQueue.async { [weak self] in
            do {
                let result = try Storage.shared.saveClipAsSnippetResult(
                    id: clipID, folderID: folderID
                )
                DispatchQueue.main.async {
                    let snippet = result.snippet
                    if result.wasCreated, let snippetID = snippet.id {
                        SnippetsEditorWindowController.shared.show(snippetID: snippetID)
                    }
                    self?.showFeedback(
                        result.wasCreated ? "Сниппет сохранён" : "Такой сниппет уже есть в этой папке"
                    )
                }
            } catch let error as LocalizedError {
                DispatchQueue.main.async { self?.showFeedback(error.errorDescription ?? "Не удалось сохранить сниппет") }
            } catch {
                DispatchQueue.main.async { self?.showFeedback("Не удалось сохранить сниппет") }
            }
        }
    }

    @objc private func openHistorySearch() {
        activeMenu?.cancelTracking()
        let target = captureTargetApplication()
        HistorySearchPanelController.shared.show(
            targetPID: target?.processIdentifier,
            paste: { [weak self] id, plainText, copyOnly, targetPID in
                self?.performHistoryPaste(id: id, plainText: plainText, copyOnly: copyOnly, targetPID: targetPID)
            },
            save: { [weak self] id in self?.saveHistoryClipAsSnippet(id: id) },
            open: { [weak self] id in self?.openClipTarget(id: id) }
        )
    }

    private func performHistoryPaste(id: Int64, plainText: Bool, copyOnly: Bool, targetPID: pid_t?) {
        let sender = NSMenuItem()
        sender.representedObject = NSNumber(value: id)
        var modifiers: NSEvent.ModifierFlags = []
        if plainText { modifiers.insert(.shift) }
        if copyOnly { modifiers.insert(.command) }
        pasteClip(sender, forcedModifiers: modifiers, destinationPID: targetPID)
    }

    @objc private func quickPasteClip(_ sender: NSMenuItem) {
        pasteClip(sender, forcedModifiers: actionModifiers.subtracting(.command), destinationPID: targetPID)
    }

    /// Capture the activating event, not the key state after menu tracking ends.
    private var actionModifiers: NSEvent.ModifierFlags {
        (NSApp.currentEvent?.modifierFlags ?? NSEvent.modifierFlags)
            .intersection(.deviceIndependentFlagsMask)
    }

    private func pasteClip(_ sender: NSMenuItem, forcedModifiers: NSEvent.ModifierFlags?, destinationPID: pid_t?) {
        guard let id = (sender.representedObject as? NSNumber)?.int64Value else { return }
        let capturedTargetPID = destinationPID
        let modifiers = forcedModifiers ?? actionModifiers
        let correctLayout = modifiers.contains(.control)
        let plainText = correctLayout || modifiers.contains(.shift) || Settings.preferPlainText
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
        pasteSnippet(sender, copyOnly: actionModifiers.contains(.command))
    }

    @objc private func quickPasteSnippet(_ sender: NSMenuItem) {
        pasteSnippet(sender, copyOnly: false)
    }

    private func pasteSnippet(_ sender: NSMenuItem, copyOnly: Bool) {
        guard let id = (sender.representedObject as? NSNumber)?.int64Value else { return }
        let capturedTargetPID = targetPID
        let clipboard = NSPasteboard.general.string(forType: .string)
        dataQueue.async { [weak self] in
            do {
                guard var snippet = try Storage.shared.fetchSnippet(id: id) else {
                    DispatchQueue.main.async { self?.showFeedback("Сниппет уже удалён") }
                    return
                }
                snippet.content = try SnippetRenderer.render(snippet.content, clipboard: clipboard)
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
            showFeedback("Лимит истории достигнут — новое не сохранено")
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
        alert.informativeText = "Сниппеты останутся на месте."
        alert.addButton(withTitle: "Удалить")
        alert.addButton(withTitle: "Отмена")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        Task { @MainActor [weak self] in
            do {
                let message = try await HistoryCleanupCoordinator.shared.run {
                    let removed = try Storage.shared.clearHistory(
                        includePinned: true,
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
        PreferencesWindowController.shared.show(section: .version)
        UpdateChecker.shared.check()
    }

    /// NSMenu actions are explicitly targeted at this controller. Forwarding
    /// `NSApplication.terminate(_:)` with that target leaves AppKit without a
    /// responder and disables the item, so quit uses a real local action.
    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
}
