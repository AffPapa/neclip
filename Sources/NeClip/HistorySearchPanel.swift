import AppKit

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

    private let dataQueue = DispatchQueue(label: "org.affpapa.neclip.history-search", qos: .userInitiated)
    private let searchField = NSSearchField()
    private let kindPopup = NSPopUpButton()
    private let appPopup = NSPopUpButton()
    private let datePopup = NSPopUpButton()
    private let tableView = NSTableView()
    private let countLabel = NSTextField(labelWithString: "")
    private var window: NSPanel?
    private var results: [ClipSummary] = []
    private var targetPID: pid_t?
    private var pasteAction: ((Int64, Bool, Bool, pid_t?) -> Void)?
    private var saveAction: ((Int64) -> Void)?
    private var openAction: ((Int64) -> Void)?

    private override init() {
        super.init()
        searchField.placeholderString = "Найти в истории…"
        searchField.sendsSearchStringImmediately = true
        searchField.target = self
        searchField.action = #selector(queryChanged)

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
        kindPopup.action = #selector(queryChanged)
        datePopup.target = self
        datePopup.action = #selector(queryChanged)
        appPopup.target = self
        appPopup.action = #selector(queryChanged)

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
        self.targetPID = targetPID
        pasteAction = paste
        saveAction = save
        openAction = open
        if window == nil { buildWindow() }
        refreshApps()
        searchField.stringValue = ""
        kindPopup.selectItem(at: 0)
        datePopup.selectItem(at: 0)
        reloadResults()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(searchField)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        pasteAction = nil
        saveAction = nil
        openAction = nil
        return true
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
        let actions = NSStackView(views: [paste, plain, copy, save, open])
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

    private func refreshApps() {
        dataQueue.async { [weak self] in
            let apps = (try? Storage.shared.clipAppBundleIDs()) ?? []
            DispatchQueue.main.async {
                guard let self else { return }
                self.appPopup.removeAllItems()
                self.appPopup.addItem(withTitle: "Все приложения")
                self.appPopup.lastItem?.representedObject = ""
                for app in apps {
                    self.appPopup.addItem(withTitle: app)
                    self.appPopup.lastItem?.representedObject = app
                }
            }
        }
    }

    @objc private func queryChanged() {
        reloadResults()
    }

    private func reloadResults() {
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
            let values = (try? Storage.shared.searchClipSummaries(
                query: query, kind: selectedKind, appBundleID: app, createdAfter: createdAfter, limit: 2_000
            )) ?? []
            DispatchQueue.main.async {
                guard let self else { return }
                self.results = values
                self.tableView.reloadData()
                if !values.isEmpty { self.tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
                self.countLabel.stringValue = values.isEmpty ? "Ничего не найдено" : "Найдено: \(values.count)"
            }
        }
    }

    private var selectedID: Int64? {
        guard tableView.selectedRow >= 0, tableView.selectedRow < results.count else { return nil }
        return results[tableView.selectedRow].id
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

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = results[row]
        let cell = NSTableCellView()
        let title = NSTextField(labelWithString: item.title)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        let detail = NSTextField(labelWithString: [item.kind.rawValue, item.appBundleID, item.text].compactMap { $0 }.joined(separator: " · "))
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [title, detail])
        stack.orientation = .vertical
        stack.spacing = 2
        cell.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }
}
