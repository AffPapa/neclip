import AppKit
import Carbon

/// Keyboard commands accepted by the search surface. Keeping the mapping
/// separate makes the same Return/plain/copy model testable without creating a
/// window or touching a user's history.
enum HistorySearchKeyboardAction: Equatable {
    case passThrough
    case pasteOriginal
    case pastePlain
    case copyOnly
    case moveSelection(Int)
    case dismiss

    static func resolve(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Self {
        let flags = modifiers.intersection([.command, .shift, .control, .option])
        // Leave VoiceOver, text editing and input-method commands to AppKit.
        guard flags.isDisjoint(with: [.control, .option]) else { return .passThrough }
        switch keyCode {
        case UInt16(kVK_Return), UInt16(kVK_ANSI_KeypadEnter):
            if flags.contains(.command) { return .copyOnly }
            if flags.contains(.shift) { return .pastePlain }
            return .pasteOriginal
        case UInt16(kVK_UpArrow):
            guard flags.isEmpty else { return .passThrough }
            return .moveSelection(-1)
        case UInt16(kVK_DownArrow):
            guard flags.isEmpty else { return .passThrough }
            return .moveSelection(1)
        case UInt16(kVK_Escape):
            guard flags.isEmpty else { return .passThrough }
            return .dismiss
        default:
            return .passThrough
        }
    }
}

/// A serial worker cannot cancel SQLite while it is executing, but it must not
/// spend time on stale keystrokes that are still queued behind it. This lock is
/// intentionally small and contains no history contents.
final class HistorySearchRequestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    @discardableResult
    func begin() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        return generation
    }

    func isCurrent(_ value: UInt64) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return generation == value
    }
}

private final class HistorySearchCellView: NSTableCellView {
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureView()
    }

    func configure(with item: ClipSummary) {
        titleLabel.stringValue = item.title
        detailLabel.stringValue = [item.kind.rawValue, item.appBundleID, item.text]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func configureView() {
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        detailLabel.font = .systemFont(ofSize: 11)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.spacing = 2
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

/// A small, temporary search surface. It is intentionally separate from the
/// native history menu so Command-F has a real first responder and a stable
/// selected clip while the frontmost paste target remains captured.
@MainActor
final class HistorySearchPanelController: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate {
    static let shared = HistorySearchPanelController()

    private enum KindFilter: String {
        case all, text, image, file
    }

    private enum DateFilter: String {
        case all, today, week, month
    }

    private let storage: Storage
    private let dataQueue: DispatchQueue
    private let searchField = NSSearchField()
    private let kindPopup = NSPopUpButton()
    private let appPopup = NSPopUpButton()
    private let datePopup = NSPopUpButton()
    private let tableView = NSTableView()
    private let countLabel = NSTextField(labelWithString: "")
    private(set) var window: NSPanel?
    private var results: [ClipSummary] = []
    private var targetPID: pid_t?
    private var pasteAction: ((Int64, Bool, Bool, pid_t?) -> Void)?
    private var saveAction: ((Int64) -> Void)?
    private var openAction: ((Int64) -> Void)?
    private let requestGate = HistorySearchRequestGate()
    private var pendingTextSearch: DispatchWorkItem?
    private var localKeyMonitor: Any?
    private var pasteButton: NSButton?
    private var plainButton: NSButton?
    private var copyButton: NSButton?
    private var saveButton: NSButton?
    private var openButton: NSButton?
    private var retryButton: NSButton?
    private var sessionOpen = false

    init(storage: Storage = .shared,
         dataQueue: DispatchQueue = DispatchQueue(label: "org.affpapa.neclip.history-search", qos: .userInitiated)) {
        self.storage = storage
        self.dataQueue = dataQueue
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(storageDidChange(_:)),
                                              name: .neClipStorageDidChange, object: storage)
        searchField.placeholderString = "Найти в истории…"
        searchField.sendsSearchStringImmediately = true
        searchField.target = self
        searchField.action = #selector(searchFieldChanged)

        configurePopup(kindPopup, values: [
            ("Все типы", KindFilter.all.rawValue),
            ("Текст", KindFilter.text.rawValue),
            ("Изображения", KindFilter.image.rawValue),
            ("Файлы", KindFilter.file.rawValue)
        ])
        configurePopup(datePopup, values: [
            ("Всё время", DateFilter.all.rawValue),
            ("Сегодня", DateFilter.today.rawValue),
            ("Последние 7 дней", DateFilter.week.rawValue),
            ("Последние 30 дней", DateFilter.month.rawValue)
        ])
        kindPopup.target = self
        kindPopup.action = #selector(filterChanged)
        datePopup.target = self
        datePopup.action = #selector(filterChanged)
        appPopup.target = self
        appPopup.action = #selector(filterChanged)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.title = "История"
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.delegate = self
        tableView.dataSource = self
        tableView.doubleAction = #selector(pasteOriginal)
        tableView.target = self
        tableView.allowsEmptySelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        countLabel.textColor = .secondaryLabelColor
        countLabel.font = .systemFont(ofSize: 11)
    }

    func show(
        targetPID: pid_t?,
        paste: @escaping (Int64, Bool, Bool, pid_t?) -> Void,
        save: @escaping (Int64) -> Void,
        open: @escaping (Int64) -> Void
    ) {
        prepare(targetPID: targetPID, paste: paste, save: save, open: open)
        if localKeyMonitor == nil { installKeyboardMonitor() }
        positionWindowOnPointerScreen()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)
    }

    /// Prepare the search independently of presentation, including for an
    /// isolated in-memory history without activating a window.
    func prepare(
        targetPID: pid_t?,
        paste: @escaping (Int64, Bool, Bool, pid_t?) -> Void,
        save: @escaping (Int64) -> Void,
        open: @escaping (Int64) -> Void
    ) {
        sessionOpen = true
        self.targetPID = targetPID
        pasteAction = paste
        saveAction = save
        openAction = open
        if window == nil { buildWindow() }
        searchField.stringValue = ""
        kindPopup.selectItem(at: 0)
        // The app list is loaded asynchronously. Reset this filter before the
        // first query so a previous session cannot silently constrain a new
        // session while the UI says “Все приложения”.
        appPopup.selectItem(at: 0)
        datePopup.selectItem(at: 0)
        reloadResults()
    }

    func windowWillClose(_ notification: Notification) {
        // close() as well as the close button must erase the retained results
        // and reject outstanding database completions.
        sessionOpen = false
        invalidateResults()
        pasteAction = nil
        saveAction = nil
        openAction = nil
        targetPID = nil
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    private func buildWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "NeClip — Поиск истории"
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.minSize = NSSize(width: 600, height: 380)
        panel.delegate = self

        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.documentView = tableView

        let filters = NSStackView(views: [searchField, kindPopup, appPopup, datePopup])
        filters.orientation = .horizontal
        filters.spacing = 8
        filters.distribution = .fill
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        appPopup.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let paste = button("Вставить", #selector(pasteOriginal))
        let plain = button("Обычный текст", #selector(pastePlain))
        let copy = button("Только скопировать", #selector(copyOnly))
        let save = button("Сохранить в сниппеты", #selector(saveAsSnippet))
        let open = button("Открыть", #selector(openTarget))
        let retry = button("Повторить", #selector(retrySearch))
        pasteButton = paste
        plainButton = plain
        copyButton = copy
        saveButton = save
        openButton = open
        retryButton = retry
        retry.isHidden = true
        let actions = NSStackView(views: [paste, plain, copy, save, open, retry])
        actions.orientation = .horizontal
        actions.spacing = 8
        actions.alignment = .centerY

        let root = NSStackView(views: [filters, scroll, countLabel, actions])
        root.orientation = .vertical
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        filters.setContentHuggingPriority(.required, for: .vertical)
        actions.setContentHuggingPriority(.required, for: .vertical)
        panel.contentView = root
        window = panel
    }

    private func button(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    private func configurePopup(_ popup: NSPopUpButton, values: [(String, String)]) {
        popup.removeAllItems()
        for (title, value) in values {
            popup.addItem(withTitle: title)
            popup.lastItem?.representedObject = value
        }
    }

    private func refreshApps(generation: UInt64) {
        let storage = storage, requestGate = requestGate
        dataQueue.async { [weak self] in
            guard requestGate.isCurrent(generation) else { return }
            let apps = (try? storage.clipAppBundleIDs()) ?? []
            DispatchQueue.main.async {
                guard let self, requestGate.isCurrent(generation) else { return }
                let selected = self.appPopup.selectedItem?.representedObject as? String
                self.appPopup.removeAllItems()
                self.appPopup.addItem(withTitle: "Все приложения")
                self.appPopup.lastItem?.representedObject = ""
                for app in apps {
                    self.appPopup.addItem(withTitle: app)
                    self.appPopup.lastItem?.representedObject = app
                }
                var selectionDisappeared = false
                if let selected, !selected.isEmpty {
                    if let index = self.appPopup.itemArray.firstIndex(where: {
                        ($0.representedObject as? String) == selected
                    }) {
                        self.appPopup.selectItem(at: index)
                    } else {
                        selectionDisappeared = true
                    }
                }
                // The popup now truthfully says “All applications”; rerun the
                // query with that same filter rather than leaving an empty
                // result list produced by an application that no longer exists.
                if selectionDisappeared { self.reloadResults() }
            }
        }
    }

    @objc private func searchFieldChanged() {
        invalidateResults()
        let work = DispatchWorkItem { [weak self] in
            self?.reloadResults()
        }
        pendingTextSearch = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(120), execute: work)
    }

    @objc private func filterChanged() {
        reloadResults()
    }

    @objc private func storageDidChange(_ notification: Notification) {
        guard StorageChangeDomain.from(notification) != .snippets else { return }
        // Clear both visible text and queued replies before starting a fresh
        // read. Full erasure must not leave private text in the app filter.
        if StorageChangeDomain.from(notification) == .all {
            appPopup.removeAllItems()
            appPopup.addItem(withTitle: "Все приложения")
            appPopup.lastItem?.representedObject = ""
        }
        if sessionOpen { reloadResults() }
        else { invalidateResults() }
    }

    @discardableResult
    private func invalidateResults() -> UInt64 {
        let generation = requestGate.begin()
        pendingTextSearch?.cancel()
        pendingTextSearch = nil
        results = []
        tableView.reloadData()
        updateActionButtons()
        countLabel.stringValue = sessionOpen ? "Поиск…" : ""
        retryButton?.isHidden = true
        retryButton?.isEnabled = false
        return generation
    }

    private func reloadResults() {
        let generation = invalidateResults()
        guard sessionOpen else { return }
        let requestGate = requestGate
        let storage = storage
        let query = searchField.stringValue
        let kind = (kindPopup.selectedItem?.representedObject as? String).flatMap { KindFilter(rawValue: $0) }
        let app = appPopup.selectedItem?.representedObject as? String
        let createdAfter: Date?
        switch datePopup.selectedItem?.representedObject as? String {
        case DateFilter.today.rawValue: createdAfter = Calendar.current.startOfDay(for: Date())
        case DateFilter.week.rawValue: createdAfter = Date().addingTimeInterval(-7 * 86_400)
        case DateFilter.month.rawValue: createdAfter = Date().addingTimeInterval(-30 * 86_400)
        default: createdAfter = nil
        }
        let selectedKind: ClipKind? = switch kind {
        case .text: .text
        case .image: .image
        case .file: .file
        default: nil
        }
        dataQueue.async { [weak self] in
            guard requestGate.isCurrent(generation) else { return }
            let values: [ClipSummary]?
            do {
                values = try storage.searchClipSummaries(
                    query: query, kind: selectedKind, appBundleID: app, createdAfter: createdAfter, limit: 2_000
                )
            } catch {
                values = nil
            }
            guard requestGate.isCurrent(generation) else { return }
            DispatchQueue.main.async {
                guard let self, requestGate.isCurrent(generation) else { return }
                guard let values else {
                    self.results = []
                    self.tableView.reloadData()
                    self.countLabel.stringValue = "Не удалось загрузить историю"
                    self.retryButton?.isHidden = false
                    self.retryButton?.isEnabled = true
                    self.updateActionButtons()
                    return
                }
                self.results = values
                self.tableView.reloadData()
                if !values.isEmpty { self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
                self.countLabel.stringValue = values.isEmpty ? "Ничего не найдено" : "Найдено: \(values.count)"
                self.retryButton?.isHidden = true
                self.retryButton?.isEnabled = false
                self.updateActionButtons()
            }
        }
        refreshApps(generation: generation)
    }

    @objc private func retrySearch() { reloadResults() }

    /// Resolve against the actual first responder, including the shared field
    /// editor. Filters/buttons and an active IME composition keep native keys.
    func keyboardAction(for event: NSEvent) -> HistorySearchKeyboardAction {
        guard let window, event.window === window else { return .passThrough }
        let responder = window.firstResponder
        if let editor = responder as? NSTextView, editor.hasMarkedText() { return .passThrough }
        guard responder === tableView || responder === searchField
                || (searchField.currentEditor() != nil && responder === searchField.currentEditor()) else {
            return .passThrough
        }
        return HistorySearchKeyboardAction.resolve(keyCode: event.keyCode, modifiers: event.modifierFlags)
    }

    private func installKeyboardMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.window else { return event }
            switch self.keyboardAction(for: event) {
            case .pasteOriginal:
                self.pasteOriginal()
            case .pastePlain:
                self.pastePlain()
            case .copyOnly:
                self.copyOnly()
            case .moveSelection(let delta):
                self.moveSelection(by: delta)
            case .dismiss:
                self.window?.close()
            case .passThrough:
                return event
            }
            return nil
        }
    }

    private func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let current = tableView.selectedRow < 0 ? 0 : tableView.selectedRow
        let next = min(max(current + delta, 0), results.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
        updateActionButtons()
    }

    private func positionWindowOnPointerScreen() {
        guard let window else { return }
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(pointer) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        var frame = window.frame
        frame.origin.x = visible.midX - frame.width / 2
        frame.origin.y = visible.midY - frame.height / 2
        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)
        window.setFrame(frame, display: false)
    }

    private var selectedID: Int64? {
        guard tableView.selectedRow >= 0, tableView.selectedRow < results.count else { return nil }
        return results[tableView.selectedRow].id
    }

    private var selectedClip: ClipSummary? {
        guard tableView.selectedRow >= 0, tableView.selectedRow < results.count else { return nil }
        return results[tableView.selectedRow]
    }

    private func updateActionButtons() {
        let selected = selectedClip
        pasteButton?.isEnabled = selected != nil
        plainButton?.isEnabled = selected != nil
        copyButton?.isEnabled = selected != nil
        saveButton?.isEnabled = selected?.kind == .text
        guard let selected else {
            openButton?.isEnabled = false
            return
        }
        let item = ClipItem(
            id: selected.id,
            kind: selected.kind,
            title: selected.title,
            text: selected.text,
            appBundleID: selected.appBundleID,
            createdAt: selected.createdAt,
            isPinned: selected.isPinned
        )
        openButton?.isEnabled = HistoryItemActionResolver.openTarget(for: item) != nil
    }

    @objc private func pasteOriginal() {
        guard let id = selectedID else { return }
        pasteAction?(id, false, false, targetPID)
        window?.close()
    }

    @objc private func pastePlain() {
        guard let id = selectedID else { return }
        pasteAction?(id, true, false, targetPID)
        window?.close()
    }

    @objc private func copyOnly() {
        guard let id = selectedID else { return }
        pasteAction?(id, false, true, targetPID)
        window?.close()
    }

    @objc private func saveAsSnippet() {
        guard let id = selectedID else { return }
        saveAction?(id)
        window?.close()
    }

    @objc private func openTarget() {
        guard let id = selectedID else { return }
        openAction?(id)
        window?.close()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateActionButtons()
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = results[row]
        let identifier = NSUserInterfaceItemIdentifier("HistorySearchCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? HistorySearchCellView)
            ?? HistorySearchCellView(frame: .zero)
        cell.identifier = identifier
        cell.configure(with: item)
        return cell
    }
}
