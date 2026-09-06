import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private let monitor = ClipboardMonitor()
    private var hotKeyWarnings: [String] = []
    private let manualLayoutCorrection = ManualLayoutCorrectionService()
    private let automaticLayoutCorrection = AutoLayoutController()
    private let applicationLayoutMemory = ApplicationLayoutMemoryController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        HistoryCleanupCoordinator.shared.attach(monitor)
        configureApplicationMenu()
        statusBar = StatusBarController()
        DispatchQueue.global(qos: .utility).async {
            try? Storage.shared.installStarterSnippetsIfNeeded(force: false)
        }

        HotKeyCoordinator.shared.onWarningsChanged = { [weak self] warnings in
            self?.hotKeyWarnings = warnings
            self?.refreshHotKeyWarnings()
        }
        HotKeyCoordinator.shared.onShortcutChanged = { [weak self] action, shortcut in
            self?.statusBar.refreshShortcutPresentation()
            self?.configureApplicationMenu()
            if action == .manualCorrection {
                self?.automaticLayoutCorrection.updateManualShortcut(shortcut)
            }
        }
        HotKeyCoordinator.shared.start(
            historyAction: { [weak self] in
                MainActor.assumeIsolated { self?.statusBar.showHistory() }
            },
            snippetsAction: { [weak self] in
                MainActor.assumeIsolated { self?.statusBar.showSnippets() }
            },
            sequentialPasteAction: { [weak self] in
                MainActor.assumeIsolated { self?.statusBar.pasteNextSequentially() }
            },
            manualCorrectionAction: { [weak self] in
                MainActor.assumeIsolated { self?.correctLayoutOrUndo() }
            },
            disableAutomaticCorrectionAction: { [weak self] in
                MainActor.assumeIsolated { self?.disableAutomaticLayoutCorrection() }
            }
        )
        refreshHotKeyWarnings()

        automaticLayoutCorrection.onFeedback = { [weak self] message in
            self?.statusBar.showLayoutFeedback(message)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(layoutSettingsChanged),
            name: .neClipLayoutSettingsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(manualLayoutCorrectionRequested),
            name: .neClipManualLayoutCorrectionRequested,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(disableAutomaticLayoutCorrectionRequested),
            name: .neClipDisableAutomaticLayoutCorrectionRequested,
            object: nil
        )
        automaticLayoutCorrection.applySetting()
        applicationLayoutMemory.applySetting()

        // Accessibility is requested only after the onboarding explanation and
        // an explicit user action.
#if DEBUG
        let qaEnvironment = ProcessInfo.processInfo.environment
        if qaEnvironment["NECLIP_UI_TEST_REGULAR"] == "1"
            || qaEnvironment["NECLIP_UI_TEST_TAB"] != nil
            || qaEnvironment["NECLIP_UI_TEST_INSPECTOR"] == "1"
            || qaEnvironment["NECLIP_UI_TEST_EDITOR"] == "1" {
            // QA builds temporarily behave like a regular app so automated
            // accessibility inspection can address the panel by bundle ID.
            NSApp.setActivationPolicy(.regular)
        }
        if qaEnvironment["NECLIP_UI_TEST_SKIP_ONBOARDING"] != "1" {
            startMonitorAroundOnboarding()
        } else {
            monitor.start()
        }
        if qaEnvironment["NECLIP_UI_TEST_ONBOARDING"] == "1", RuntimeIdentity.isIsolatedPreview {
            DispatchQueue.main.async { OnboardingWindowController.shared.show() }
        } else if qaEnvironment["NECLIP_UI_TEST_INSPECTOR"] == "1", RuntimeIdentity.isIsolatedPreview {
            DispatchQueue.main.async {
                if let id = try? Storage.shared.insert(ClipItem(
                    kind: .text, title: "Пример для редактирования",
                    text: "Это тестовый текст. Измените его и нажмите ⌘S, чтобы сохранить.", createdAt: Date()
                )) {
                    HistoryItemInspectorWindowController.shared.show(clipID: id)
                }
            }
        } else if qaEnvironment["NECLIP_UI_TEST_EDITOR"] == "1" {
            DispatchQueue.main.async {
                SnippetsEditorWindowController.shared.show()
            }
        } else if qaEnvironment["NECLIP_UI_TEST_PREFERENCES"] == "1" {
            DispatchQueue.main.async {
                PreferencesWindowController.shared.show()
            }
        } else if let tab = qaEnvironment["NECLIP_UI_TEST_TAB"] {
            DispatchQueue.main.async { [weak self] in
                if tab == "snippets" {
                    self?.statusBar.showSnippets()
                } else {
                    self?.statusBar.showHistory()
                }
            }
        }
#else
        startMonitorAroundOnboarding()
#endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        automaticLayoutCorrection.disable()
        applicationLayoutMemory.stop()
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        PreferencesWindowController.shared.commitPendingEdits()
        guard HistoryItemInspectorWindowController.shared.prepareForTermination(),
              SnippetsEditorWindowController.shared.prepareForTermination() else {
            return .terminateCancel
        }
        guard Settings.clearHistoryOnQuit else { return .terminateNow }
        monitor.stopAndDrain()
        do {
            try Storage.shared.clearHistory(includePinned: false)
            return .terminateNow
        } catch {
            monitor.start()
            let alert = NSAlert()
            alert.messageText = "Не удалось очистить историю"
            alert.informativeText = "NeClip не завершит работу, чтобы настройка приватности не создала ложного ощущения удаления. Попробуйте ещё раз."
            alert.alertStyle = .warning
            alert.runModal()
            return .terminateCancel
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        automaticLayoutCorrection.refreshContext()
        monitor.refreshAuthorization()
        statusBar.refreshAuthorizationState()
    }

    private func configureApplicationMenu() {
        let mainMenu = NSMenu(title: "Main")
        let applicationItem = NSMenuItem()
        applicationItem.submenu = Self.makeApplicationMenu(target: self)
        mainMenu.addItem(applicationItem)
        let fileItem = NSMenuItem()
        fileItem.submenu = Self.makeFileMenu(
            historyShortcut: HotKeyCoordinator.shared.shortcut(for: .history),
            snippetsShortcut: HotKeyCoordinator.shared.shortcut(for: .snippets),
            target: self
        )
        mainMenu.addItem(fileItem)
        let editItem = NSMenuItem()
        editItem.submenu = Self.makeEditMenu()
        mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
    }

    static func makeApplicationMenu(target: AnyObject) -> NSMenu {
        let menu = NSMenu(title: RuntimeIdentity.displayName)
        let commands: [(String, Selector, String)] = [
            ("О NeClip", #selector(showAboutFromApplicationMenu), ""),
            ("Настройки…", #selector(openSettingsFromApplicationMenu), ","),
            ("Выйти из NeClip", #selector(quitFromApplicationMenu), "q")
        ]
        for (title, action, key) in commands {
            if !menu.items.isEmpty { menu.addItem(.separator()) }
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.keyEquivalentModifierMask = [.command]
            item.target = target
            menu.addItem(item)
        }
        return menu
    }

    static func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: "Правка")
        let commands: [(String, String, String, NSEvent.ModifierFlags)] = [
            ("Отменить", "undo:", "z", [.command]),
            ("Повторить", "redo:", "z", [.command, .shift]),
            ("Вырезать", "cut:", "x", [.command]),
            ("Копировать", "copy:", "c", [.command]),
            ("Вставить", "paste:", "v", [.command]),
            ("Выбрать всё", "selectAll:", "a", [.command])
        ]
        for (index, command) in commands.enumerated() {
            if index == 2 || index == 5 { menu.addItem(.separator()) }
            let item = NSMenuItem(title: command.0, action: NSSelectorFromString(command.1), keyEquivalent: command.2)
            item.keyEquivalentModifierMask = command.3
            // The focused native editor, not the clipboard monitor, owns these actions.
            item.target = nil
            menu.addItem(item)
        }
        return menu
    }

    static func makeFileMenu(
        historyShortcut: ShortcutDescriptor,
        snippetsShortcut: ShortcutDescriptor,
        target: AnyObject
    ) -> NSMenu {
        let menu = NSMenu(title: "Файл")
        let commands: [(String, Selector, ShortcutDescriptor)] = [
            ("Открыть историю", #selector(openHistoryFromApplicationMenu), historyShortcut),
            ("Открыть папки сниппетов", #selector(openSnippetsFromApplicationMenu), snippetsShortcut)
        ]
        for (title, action, shortcut) in commands {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: shortcut.keyEquivalent ?? "")
            item.keyEquivalentModifierMask = shortcut.nsEventModifiers
            item.target = target
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let closeItem = NSMenuItem(
            title: "Закрыть окно",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        closeItem.keyEquivalentModifierMask = [.command]
        // Resolve through the key window's responder chain. performClose
        // respects the snippets editor's unsaved-draft close veto.
        closeItem.target = nil
        menu.addItem(closeItem)
        return menu
    }

    @objc private func quitFromApplicationMenu() {
        NSApp.terminate(nil)
    }

    @objc private func showAboutFromApplicationMenu() {
        NSApp.activate(ignoringOtherApps: true)
        // AppKit reads the installed bundle's version/build and app icon.
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openSettingsFromApplicationMenu() {
        PreferencesWindowController.shared.show()
    }

    @objc private func openHistoryFromApplicationMenu() {
        statusBar.showHistory()
    }

    @objc private func openSnippetsFromApplicationMenu() {
        statusBar.showSnippets()
    }

    private func startMonitorAroundOnboarding() {
        let presented = OnboardingWindowController.shared.showIfNeeded { [weak self] in
            self?.monitor.start()
            self?.statusBar.refreshAuthorizationState()
        }
        if !presented { monitor.start() }
    }

    @objc private func layoutSettingsChanged() {
        automaticLayoutCorrection.applySetting()
        applicationLayoutMemory.applySetting()
    }

    @objc private func manualLayoutCorrectionRequested() {
        correctLayoutOrUndo()
    }

    @objc private func disableAutomaticLayoutCorrectionRequested() {
        disableAutomaticLayoutCorrection()
    }

    private func refreshHotKeyWarnings() {
        statusBar.setHotKeyWarnings(hotKeyWarnings)
    }

    private func disableAutomaticLayoutCorrection() {
        guard Settings.automaticLayoutCorrection else {
            statusBar.showLayoutFeedback("Автоисправление уже выключено")
            return
        }
        // Stop the event tap before publishing the setting change. The safety
        // shortcut is deliberately off-only and can never request access.
        automaticLayoutCorrection.disable()
        Settings.automaticLayoutCorrection = false
        statusBar.showLayoutFeedback("Автоисправление выключено")
    }

    private func correctLayoutOrUndo() {
        if automaticLayoutCorrection.undoLastCorrectionIfPossible(completion: { [weak self] undone in
            self?.statusBar.showLayoutFeedback(
                undone ? "Отменено · слово игнорируется до перезапуска" : "Отмена уже недоступна"
            )
        }) {
            return
        }

        manualLayoutCorrection.correctOrUndo { [weak self] result in
            self?.automaticLayoutCorrection.refreshContext()
            let message: String
            switch result {
            case .corrected:
                message = "Раскладка исправлена · \(HotKeyCoordinator.shared.shortcut(for: .manualCorrection).displayString) — отменить"
            case .undone:
                message = "Исправление отменено"
            case .nothingToCorrect:
                message = "Нечего исправлять"
            case .permissionRequired:
                message = "Нужен Универсальный доступ"
            case .protectedContext:
                message = "Защищённые поля не исправляются"
            case .unsupported:
                message = "Это поле не поддерживает безопасную замену"
            case .failed:
                message = "Не удалось исправить раскладку"
            }
            self?.statusBar.showLayoutFeedback(message)
        }
    }
}
