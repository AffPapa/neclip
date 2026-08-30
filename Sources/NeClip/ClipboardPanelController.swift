import AppKit

enum ClipboardPanelTab: Int {
    case all
    case pinned
    case snippets
}

private enum ClipboardPanelEntry {
    case clip(ClipSummary)
    case snippet(Snippet)

    var title: String {
        switch self {
        case .clip(let clip): clip.title
        case .snippet(let snippet): snippet.title
        }
    }

    var isPinned: Bool {
        switch self {
        case .clip(let clip): clip.isPinned
        case .snippet(let snippet): snippet.isPinned
        }
    }
}

@MainActor
private final class ClipboardPanel: NSPanel {
    var keyEventHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyEventHandler?(event) == true {
            return
        }
        super.sendEvent(event)
    }
}

@MainActor
final class ClipboardPanelController: NSObject {
    private let panel: ClipboardPanel
    private let searchField = NSSearchField()
    private let tabs = NSSegmentedControl(labels: ["Все", "Закреплённые", "Сниппеты"], trackingMode: .selectOne, target: nil, action: nil)
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyState = NSStackView()
    private let emptyTitle = NSTextField(labelWithString: "")
    private let emptyDetail = NSTextField(wrappingLabelWithString: "")
    private let emptyAction = NSButton(title: "", target: nil, action: nil)
    private let banner = NSTextField(labelWithString: "")
    private let bannerRow = NSStackView()
    private let resumeCaptureButton = NSButton(title: "Возобновить", target: nil, action: nil)
    private let rowMenu = NSMenu()
    private var entries: [ClipboardPanelEntry] = []
    private var selectedTab: ClipboardPanelTab = .all
    private var targetPID: pid_t?
    private var feedbackWorkItem: DispatchWorkItem?
    private var undoAction: (() -> Void)?

    override init() {
        panel = ClipboardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
        buildInterface()
    }

    func show(tab: ClipboardPanelTab) {
        targetPID = captureTargetPID()
        selectedTab = tab
        tabs.selectedSegment = tab.rawValue
        searchField.stringValue = ""
        updatePersistentBanner()
        reloadData()
        positionPanel()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func refreshIfVisible() {
        guard panel.isVisible else { return }
        reloadData()
    }

    func showFeedback(_ text: String) {
        guard panel.isVisible else { return }
        feedbackWorkItem?.cancel()
        banner.stringValue = text
        resumeCaptureButton.isHidden = true
        bannerRow.isHidden = false

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.updatePersistentBanner()
        }
        feedbackWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: item)
    }

    private func configurePanel() {
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.delegate = self
        panel.keyEventHandler = { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }
    }

    private func buildInterface() {
        let root = NSVisualEffectView()
        root.material = .popover
        root.blendingMode = .behindWindow
        root.state = .active
        panel.contentView = root

        searchField.placeholderString = "Поиск в истории и сниппетах…"
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = self
        searchField.focusRingType = .none
        searchField.setAccessibilityLabel("Поиск в истории и сниппетах")

        let settingsButton = NSButton(
            image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Настройки") ?? NSImage(),
            target: self,
            action: #selector(openPreferences)
        )
        settingsButton.bezelStyle = .accessoryBarAction
        settingsButton.isBordered = false
        settingsButton.toolTip = "Настройки"

        let searchRow = NSStackView(views: [searchField, settingsButton])
        searchRow.orientation = .horizontal
        searchRow.spacing = 8
        searchRow.alignment = .centerY
        settingsButton.widthAnchor.constraint(equalToConstant: 28).isActive = true

        tabs.target = self
        tabs.action = #selector(tabChanged(_:))
        tabs.selectedSegment = selectedTab.rawValue
        tabs.segmentStyle = .texturedRounded
        tabs.setAccessibilityLabel("Раздел")

        banner.font = .systemFont(ofSize: 12, weight: .medium)
        banner.textColor = .systemOrange
        banner.maximumNumberOfLines = 2
        resumeCaptureButton.bezelStyle = .inline
        resumeCaptureButton.controlSize = .small
        resumeCaptureButton.target = self
        resumeCaptureButton.action = #selector(resumeCapture)
        resumeCaptureButton.setContentHuggingPriority(.required, for: .horizontal)
        bannerRow.orientation = .horizontal
        bannerRow.spacing = 8
        bannerRow.alignment = .centerY
        bannerRow.addArrangedSubview(banner)
        bannerRow.addArrangedSubview(resumeCaptureButton)
        bannerRow.isHidden = true

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 52
        tableView.intercellSpacing = .zero
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.focusRingType = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(doubleClickedRow)
        tableView.setAccessibilityLabel("Результаты")
        rowMenu.delegate = self
        tableView.menu = rowMenu

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        emptyState.orientation = .vertical
        emptyState.alignment = .centerX
        emptyState.spacing = 8
        emptyTitle.font = .systemFont(ofSize: 16, weight: .semibold)
        emptyTitle.alignment = .center
        emptyDetail.textColor = .secondaryLabelColor
        emptyDetail.alignment = .center
        emptyDetail.maximumNumberOfLines = 3
        emptyAction.bezelStyle = .rounded
        emptyAction.target = self
        emptyAction.action = #selector(emptyActionPressed)
        emptyState.addArrangedSubview(emptyTitle)
        emptyState.addArrangedSubview(emptyDetail)
        emptyState.addArrangedSubview(emptyAction)

        let resultsContainer = NSView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        resultsContainer.addSubview(scrollView)
        resultsContainer.addSubview(emptyState)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: resultsContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: resultsContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: resultsContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: resultsContainer.bottomAnchor),
            emptyState.centerXAnchor.constraint(equalTo: resultsContainer.centerXAnchor),
            emptyState.centerYAnchor.constraint(equalTo: resultsContainer.centerYAnchor),
            emptyState.leadingAnchor.constraint(greaterThanOrEqualTo: resultsContainer.leadingAnchor, constant: 30),
            emptyState.trailingAnchor.constraint(lessThanOrEqualTo: resultsContainer.trailingAnchor, constant: -30)
        ])

        let footer = NSTextField(labelWithString: "↩ Вставить    ⇧↩ Без форматирования    ⌘↩ Копировать")
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .tertiaryLabelColor
        footer.alignment = .center
        footer.setAccessibilityLabel("Enter вставить, Shift Enter без форматирования, Command Enter только скопировать")

        let stack = NSStackView(views: [searchRow, tabs, bannerRow, resultsContainer, footer])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 30),
            tabs.heightAnchor.constraint(equalToConstant: 28),
            resultsContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 340)
        ])
    }

    private func captureTargetPID() -> pid_t? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.bundleIdentifier != Bundle.main.bundleIdentifier,
              !application.isTerminated else {
            return nil
        }
        return application.processIdentifier
    }

    private func positionPanel() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else {
            panel.center()
            return
        }

        let size = panel.frame.size
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 12)
        if origin.y < visibleFrame.minY {
            origin.y = min(mouse.y + 12, visibleFrame.maxY - size.height)
        }
        origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        origin.y = min(max(origin.y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)
        panel.setFrameOrigin(origin)
    }

    private func reloadData() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let search = query.isEmpty ? nil : query

        do {
            switch selectedTab {
            case .all:
                let clips = try Storage.shared.summaries(limit: 40, search: search, pinnedOnly: false)
                let snippets = try Storage.shared.allSnippets(search: search, pinnedOnly: query.isEmpty)
                entries = clips.map(ClipboardPanelEntry.clip) + snippets.map(ClipboardPanelEntry.snippet)
            case .pinned:
                let clips = try Storage.shared.summaries(limit: 40, search: search, pinnedOnly: true)
                let snippets = try Storage.shared.allSnippets(search: search, pinnedOnly: true)
                entries = clips.map(ClipboardPanelEntry.clip) + snippets.map(ClipboardPanelEntry.snippet)
            case .snippets:
                entries = try Storage.shared.allSnippets(search: search, pinnedOnly: false).map(ClipboardPanelEntry.snippet)
            }
            updateEmptyState(for: query)
        } catch {
            entries = []
            emptyTitle.stringValue = "Не удалось загрузить данные"
            emptyDetail.stringValue = "Закройте панель и попробуйте ещё раз."
            emptyAction.isHidden = true
            emptyState.isHidden = false
            scrollView.isHidden = true
            showFeedback("Ошибка хранилища")
        }

        tableView.reloadData()
        if !entries.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    private func updateEmptyState(for query: String) {
        guard entries.isEmpty else {
            emptyState.isHidden = true
            scrollView.isHidden = false
            return
        }

        scrollView.isHidden = true
        emptyState.isHidden = false
        emptyAction.isHidden = false

        if !query.isEmpty {
            emptyTitle.stringValue = "Ничего не найдено"
            emptyDetail.stringValue = "Попробуйте другой запрос."
            emptyAction.title = "Очистить поиск"
        } else if selectedTab == .pinned {
            emptyTitle.stringValue = "Нет закреплённых элементов"
            emptyDetail.stringValue = "Выберите элемент и нажмите ⌘P."
            emptyAction.isHidden = true
        } else if selectedTab == .snippets {
            emptyTitle.stringValue = "Сниппетов пока нет"
            emptyDetail.stringValue = "Создайте первый сниппет."
            emptyAction.title = "Создать сниппет"
        } else {
            emptyTitle.stringValue = "История пока пуста"
            emptyDetail.stringValue = "Скопируйте текст, изображение или файл — он появится здесь."
            emptyAction.isHidden = true
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .shift, .control])
        let character = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if modifiers == .command, let number = Int(character), (1...9).contains(number) {
            pasteEntry(at: number - 1, plainText: false, copyOnly: false)
            return true
        }

        if modifiers == .option, let number = Int(character), (1...3).contains(number) {
            selectTab(ClipboardPanelTab(rawValue: number - 1) ?? .all)
            return true
        }

        if modifiers == .command {
            switch character {
            case "p": togglePin(); return true
            case "s": saveSelectedAsSnippet(); return true
            case "z": undoLastDeletion(); return true
            default: break
            }
        }

        if event.keyCode == 51, modifiers == .command {
            deleteSelected()
            return true
        }

        if event.keyCode == 36 || event.keyCode == 76 {
            if modifiers.contains(.command) {
                pasteSelected(plainText: false, copyOnly: true)
            } else {
                pasteSelected(plainText: modifiers.contains(.shift), copyOnly: false)
            }
            return true
        }

        switch event.keyCode {
        case 125:
            moveSelection(by: 1)
            return true
        case 126:
            moveSelection(by: -1)
            return true
        case 53:
            if !searchField.stringValue.isEmpty {
                searchField.stringValue = ""
                reloadData()
            } else {
                closePanel()
            }
            return true
        default:
            return false
        }
    }

    private func selectTab(_ tab: ClipboardPanelTab) {
        selectedTab = tab
        tabs.selectedSegment = tab.rawValue
        reloadData()
    }

    private func moveSelection(by delta: Int) {
        guard !entries.isEmpty else { return }
        let current = max(tableView.selectedRow, 0)
        let next = min(max(current + delta, 0), entries.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func pasteSelected(plainText: Bool, copyOnly: Bool) {
        let row = max(tableView.selectedRow, 0)
        pasteEntry(at: row, plainText: plainText, copyOnly: copyOnly)
    }

    private func pasteEntry(at index: Int, plainText: Bool, copyOnly: Bool) {
        guard entries.indices.contains(index) else { return }
        let capturedTargetPID = targetPID
        let keepPanelOpen = copyOnly || capturedTargetPID == nil || !PasteService.isAccessibilityTrusted

        switch entries[index] {
        case .clip(let summary):
            do {
                guard let item = try Storage.shared.fetchClip(id: summary.id) else {
                    showFeedback("Элемент уже удалён")
                    reloadData()
                    return
                }
                if !keepPanelOpen { closePanel() }
                PasteService.paste(
                    item,
                    plainText: plainText,
                    targetPID: capturedTargetPID,
                    copyOnly: copyOnly
                ) { [weak self] result in
                    DispatchQueue.main.async {
                        self?.handlePasteResult(result, explicitlyCopyOnly: copyOnly, keptPanelOpen: keepPanelOpen)
                    }
                }
            } catch {
                showFeedback("Не удалось открыть элемент")
            }
        case .snippet(var snippet):
            snippet.content = SnippetRenderer.render(
                snippet.content,
                clipboard: NSPasteboard.general.string(forType: .string)
            )
            if let id = snippet.id {
                try? Storage.shared.markSnippetUsed(id: id)
            }
            if !keepPanelOpen { closePanel() }
            PasteService.paste(snippet: snippet, targetPID: capturedTargetPID, copyOnly: copyOnly) { [weak self] result in
                DispatchQueue.main.async {
                    self?.handlePasteResult(result, explicitlyCopyOnly: copyOnly, keptPanelOpen: keepPanelOpen)
                }
            }
        }
    }

    private func handlePasteResult(_ result: PasteResult, explicitlyCopyOnly: Bool, keptPanelOpen: Bool) {
        switch result {
        case .pasted:
            break
        case .copiedOnly:
            showFeedback(explicitlyCopyOnly ? "Скопировано" : "Скопировано без автовставки")
        case .copiedOnlyNoAccessibility:
            showFeedback("Скопировано. Для автовставки разрешите доступ.")
        case .copiedOnlyTargetChanged:
            if !keptPanelOpen { show(tab: selectedTab) }
            showFeedback("Целевое приложение изменилось — элемент только скопирован")
        case .failed:
            if !keptPanelOpen { show(tab: selectedTab) }
            showFeedback("Не удалось записать в буфер обмена")
        }
    }

    @objc private func togglePin() {
        guard entries.indices.contains(tableView.selectedRow) else { return }
        let entry = entries[tableView.selectedRow]
        do {
            switch entry {
            case .clip(let clip):
                try Storage.shared.setPinned(id: clip.id, pinned: !clip.isPinned)
            case .snippet(var snippet):
                snippet.isPinned.toggle()
                try Storage.shared.update(snippet)
            }
            reloadData()
        } catch {
            showFeedback("Не удалось изменить закрепление")
        }
    }

    @objc private func saveSelectedAsSnippet() {
        guard entries.indices.contains(tableView.selectedRow),
              case .clip(let summary) = entries[tableView.selectedRow] else { return }
        do {
            guard let item = try Storage.shared.fetchClip(id: summary.id) else {
                showFeedback("Элемент уже удалён")
                reloadData()
                return
            }
            guard let content = item.text, !content.isEmpty else {
                showFeedback("Этот элемент нельзя сохранить как текстовый сниппет")
                return
            }
            let folders = try Storage.shared.snippetFolders()
            let folderID: Int64
            if let existingID = folders.first?.id {
                folderID = existingID
            } else if let newID = try Storage.shared.addFolder(title: "Быстрые ответы")?.id {
                folderID = newID
            } else {
                throw ClipboardPanelError.missingFolder
            }
            _ = try Storage.shared.addSnippet(
                folderID: folderID,
                title: String(summary.title.prefix(60)),
                content: content,
                keyword: nil
            )
            showFeedback("Сохранено в сниппеты")
        } catch {
            showFeedback("Не удалось создать сниппет")
        }
    }

    @objc private func deleteSelected() {
        guard entries.indices.contains(tableView.selectedRow) else { return }
        let entry = entries[tableView.selectedRow]
        do {
            switch entry {
            case .clip(let clip):
                guard let removed = try Storage.shared.removeClip(id: clip.id) else {
                    showFeedback("Элемент уже удалён")
                    reloadData()
                    return
                }
                undoAction = { [weak self] in
                    do {
                        try Storage.shared.restoreClip(removed)
                        self?.showFeedback("Восстановлено")
                        self?.reloadData()
                    } catch {
                        self?.showFeedback("Не удалось восстановить")
                    }
                }
            case .snippet(let snippet):
                guard let id = snippet.id else { return }
                try Storage.shared.deleteSnippet(id: id)
                undoAction = { [weak self] in
                    do {
                        _ = try Storage.shared.addSnippet(
                            folderID: snippet.folderID,
                            title: snippet.title,
                            content: snippet.content,
                            keyword: snippet.keyword
                        )
                        self?.showFeedback("Восстановлено")
                        self?.reloadData()
                    } catch {
                        self?.showFeedback("Не удалось восстановить")
                    }
                }
            }
            reloadData()
            showFeedback("Удалено — ⌘Z вернуть")
        } catch {
            showFeedback("Не удалось удалить")
        }
    }

    private func undoLastDeletion() {
        guard let action = undoAction else { return }
        undoAction = nil
        action()
    }

    private func updatePersistentBanner() {
        if Settings.isCapturePaused {
            banner.stringValue = "Запись истории приостановлена"
            resumeCaptureButton.isHidden = false
            bannerRow.isHidden = false
        } else if Storage.shared.startupError != nil {
            banner.stringValue = "База недоступна — история временно хранится только до выхода"
            resumeCaptureButton.isHidden = true
            bannerRow.isHidden = false
        } else {
            resumeCaptureButton.isHidden = true
            bannerRow.isHidden = true
        }
    }

    private func closePanel() {
        feedbackWorkItem?.cancel()
        panel.orderOut(nil)
        searchField.stringValue = ""
        targetPID = nil
    }

    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        selectTab(ClipboardPanelTab(rawValue: sender.selectedSegment) ?? .all)
        panel.makeFirstResponder(searchField)
    }

    @objc private func emptyActionPressed() {
        if !searchField.stringValue.isEmpty {
            searchField.stringValue = ""
            reloadData()
            panel.makeFirstResponder(searchField)
        } else if selectedTab == .snippets {
            SnippetsEditorWindowController.shared.show()
        }
    }

    @objc private func doubleClickedRow() {
        guard tableView.clickedRow >= 0 else { return }
        pasteEntry(at: tableView.clickedRow, plainText: false, copyOnly: false)
    }

    @objc private func togglePinButton(_ sender: NSButton) {
        guard entries.indices.contains(sender.tag) else { return }
        tableView.selectRowIndexes(IndexSet(integer: sender.tag), byExtendingSelection: false)
        togglePin()
    }

    @objc private func resumeCapture() {
        Settings.resumeCapture()
        updatePersistentBanner()
        reloadData()
    }

    @objc private func pasteFromMenu() {
        pasteSelected(plainText: false, copyOnly: false)
    }

    @objc private func pastePlainTextFromMenu() {
        pasteSelected(plainText: true, copyOnly: false)
    }

    @objc private func copyFromMenu() {
        pasteSelected(plainText: false, copyOnly: true)
    }

    @objc private func openPreferences() {
        closePanel()
        PreferencesWindowController.shared.show()
    }
}

extension ClipboardPanelController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        reloadData()
    }
}

extension ClipboardPanelController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        closePanel()
    }
}

extension ClipboardPanelController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = tableView.clickedRow
        guard entries.indices.contains(row) else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)

        menu.addItem(contextItem("Вставить", action: #selector(pasteFromMenu), key: "\r"))
        menu.addItem(contextItem("Вставить без форматирования", action: #selector(pastePlainTextFromMenu), key: "\r", modifiers: [.shift]))
        menu.addItem(contextItem("Копировать", action: #selector(copyFromMenu), key: "\r", modifiers: [.command]))
        menu.addItem(.separator())

        let pinTitle = entries[row].isPinned ? "Открепить" : "Закрепить"
        menu.addItem(contextItem(pinTitle, action: #selector(togglePin), key: "p", modifiers: [.command]))
        if case .clip = entries[row] {
            menu.addItem(contextItem("Сохранить как сниппет", action: #selector(saveSelectedAsSnippet), key: "s", modifiers: [.command]))
        }
        menu.addItem(contextItem("Удалить", action: #selector(deleteSelected), key: "\u{8}", modifiers: [.command]))
    }

    private func contextItem(
        _ title: String,
        action: Selector,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = []
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = modifiers
        item.target = self
        return item
    }
}

extension ClipboardPanelController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ClipboardEntryCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? ClipboardEntryCellView)
            ?? ClipboardEntryCellView(identifier: identifier)
        let entry = entries[row]

        switch entry {
        case .clip(let clip):
            let metadata = AppMetadataStore.shared.metadata(for: clip.appBundleID)
            let icon: NSImage
            if clip.kind == .image, let data = clip.thumbnail, let image = NSImage(data: data) {
                icon = image
            } else if clip.kind == .file {
                icon = NSImage(systemSymbolName: "doc", accessibilityDescription: "Файл") ?? metadata.icon
            } else {
                icon = metadata.icon
            }
            cell.configure(
                icon: icon,
                title: clip.title,
                subtitle: "\(metadata.name) · \(relativeDate(clip.createdAt))",
                pinned: clip.isPinned,
                shortcut: row < 9 ? "⌘\(row + 1)" : nil,
                row: row,
                target: self,
                action: #selector(togglePinButton(_:))
            )
        case .snippet(let snippet):
            let icon = NSImage(systemSymbolName: "scissors", accessibilityDescription: "Сниппет") ?? NSImage()
            let keyword = snippet.keyword?.isEmpty == false ? " · \(snippet.keyword!)" : ""
            cell.configure(
                icon: icon,
                title: snippet.title,
                subtitle: "Сниппет\(keyword)",
                pinned: snippet.isPinned,
                shortcut: row < 9 ? "⌘\(row + 1)" : nil,
                row: row,
                target: self,
                action: #selector(togglePinButton(_:))
            )
        }
        return cell
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .current
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

@MainActor
private final class ClipboardEntryCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let pinButton = NSButton()

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        buildInterface()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(
        icon: NSImage,
        title: String,
        subtitle: String,
        pinned: Bool,
        shortcut: String?,
        row: Int,
        target: AnyObject,
        action: Selector
    ) {
        iconView.image = icon
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        shortcutLabel.stringValue = shortcut ?? ""
        pinButton.image = NSImage(
            systemSymbolName: pinned ? "pin.fill" : "pin",
            accessibilityDescription: pinned ? "Открепить" : "Закрепить"
        )
        pinButton.contentTintColor = pinned ? .controlAccentColor : .tertiaryLabelColor
        pinButton.tag = row
        pinButton.target = target
        pinButton.action = action
        setAccessibilityLabel("\(title), \(subtitle)\(pinned ? ", закреплено" : "")")
    }

    private func buildInterface() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail

        let labels = NSStackView(views: [titleLabel, subtitleLabel])
        labels.orientation = .vertical
        labels.spacing = 3
        labels.alignment = .leading

        shortcutLabel.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
        shortcutLabel.textColor = .tertiaryLabelColor
        shortcutLabel.alignment = .right
        shortcutLabel.setContentHuggingPriority(.required, for: .horizontal)

        pinButton.isBordered = false
        pinButton.bezelStyle = .accessoryBarAction
        pinButton.setButtonType(.momentaryChange)
        pinButton.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView(views: [iconView, labels, shortcutLabel, pinButton])
        row.orientation = .horizontal
        row.spacing = 9
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            pinButton.widthAnchor.constraint(equalToConstant: 24)
        ])
    }
}

private enum ClipboardPanelError: Error {
    case missingFolder
}
