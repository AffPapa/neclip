import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private let monitor = ClipboardMonitor()
    private var hotKeyWarnings: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.removeRetiredPreferences()
#if DEBUG
        if RuntimeIdentity.isIsolatedPreview, ProcessInfo.processInfo.environment["NECLIP_QA_STARTUP_REPORT"] == "1" {
            print("NeClip QA: applicationDidFinishLaunching")
        }
#endif
        HistoryCleanupCoordinator.shared.attach(monitor)
        configureApplicationMenu()
        statusBar = StatusBarController()
        statusBar.isClipboardGenerationExcluded = { [weak self] generation in
            self?.monitor.isClipboardGenerationExcluded(generation) ?? true
        }
        statusBar.onSnippetCopied = { [weak self] text, sourceBundleID, clipboardContext in
            self?.monitor.recordSnippet(text, sourceBundleID: sourceBundleID, clipboardContext: clipboardContext)
        }
        DispatchQueue.global(qos: .utility).async {
            try? Storage.shared.installStarterSnippetsIfNeeded(force: false)
        }

        HotKeyCoordinator.shared.onWarningsChanged = { [weak self] warnings in
            self?.hotKeyWarnings = warnings
            self?.refreshHotKeyWarnings()
        }
        HotKeyCoordinator.shared.onShortcutChanged = { [weak self] _, _ in
            self?.statusBar.refreshShortcutPresentation()
            self?.configureApplicationMenu()
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
            }

        )
        refreshHotKeyWarnings()

        // Accessibility is requested only after the onboarding explanation and
        // an explicit user action.
#if DEBUG
        let qaEnvironment = ProcessInfo.processInfo.environment
        if qaEnvironment["NECLIP_UI_TEST_REGULAR"] == "1"
            || RuntimeIdentity.isIsolatedPreview
            || qaEnvironment["NECLIP_UI_TEST_TAB"] != nil
            || qaEnvironment["NECLIP_UI_TEST_EDITOR"] == "1" {
            // QA builds temporarily behave like a regular app so automated
            // accessibility inspection can address the panel by bundle ID.
            NSApp.setActivationPolicy(.regular)
        }
        if !RuntimeIdentity.isIsolatedPreview, qaEnvironment["NECLIP_UI_TEST_SKIP_ONBOARDING"] != "1" {
            startMonitorAroundOnboarding()
        } else {
            monitor.start()
        }
        if qaEnvironment["NECLIP_UI_TEST_ONBOARDING"] == "1", RuntimeIdentity.isIsolatedPreview {
            DispatchQueue.main.async { OnboardingWindowController.shared.show() }
        } else if qaEnvironment["NECLIP_UI_TEST_EDITOR"] == "1" {
            DispatchQueue.main.async {
                SnippetsEditorWindowController.shared.show()
            }
        } else if qaEnvironment["NECLIP_UI_TEST_PREFERENCES"] == "1" || RuntimeIdentity.isIsolatedPreview {
            DispatchQueue.main.async {
                let section = qaEnvironment["NECLIP_UI_TEST_SECTION"].flatMap(PreferencesSection.init(rawValue:))
                PreferencesWindowController.shared.show(section: section)
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
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        PreferencesWindowController.shared.commitPendingEdits()
        guard SnippetsEditorWindowController.shared.prepareForTermination() else {
            return .terminateCancel
        }
        guard Settings.clearHistoryOnQuit else { return .terminateNow }
        monitor.stopAndDrain()
        do {
            try Storage.shared.clearHistory(includePinned: true)
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
        PreferencesWindowController.shared.show(section: .version)
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

    private func refreshHotKeyWarnings() {
        statusBar.setHotKeyWarnings(hotKeyWarnings)
    }

}
