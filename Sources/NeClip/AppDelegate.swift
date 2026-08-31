import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private let monitor = ClipboardMonitor()
    private var mainHotKey: GlobalHotKey?
    private var snippetsHotKey: GlobalHotKey?
    private var fixedHotKeyWarnings: [String] = []
    private var layoutHotKeyWarnings: [String] = []
    private let manualLayoutCorrection = ManualLayoutCorrectionService()
    private let automaticLayoutCorrection = AutoLayoutController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
        DispatchQueue.global(qos: .utility).async {
            try? Storage.shared.installStarterSnippetsIfNeeded(force: false)
        }

        // Native global shortcuts keep the app dependency-light. Handlers are
        // delivered by the application event target on the main run loop.
        mainHotKey = try? GlobalHotKey(
            shortcut: .historyReserved,
            identifier: 1
        ) { [weak self] in
            MainActor.assumeIsolated { self?.statusBar.showHistory() }
        }

        snippetsHotKey = try? GlobalHotKey(
            shortcut: .snippetsReserved,
            identifier: 2
        ) { [weak self] in
            MainActor.assumeIsolated { self?.statusBar.showSnippets() }
        }

        var hotKeyWarnings: [String] = []
        if mainHotKey == nil {
            hotKeyWarnings.append("⌘⇧V занята — история доступна через значок NeClip")
        }
        if snippetsHotKey == nil {
            hotKeyWarnings.append("⌘⇧B занята — сниппеты доступны в меню NeClip")
        }
        fixedHotKeyWarnings = hotKeyWarnings

        LayoutHotKeyCoordinator.shared.onWarningsChanged = { [weak self] warnings in
            self?.layoutHotKeyWarnings = warnings
            self?.refreshHotKeyWarnings()
        }
        LayoutHotKeyCoordinator.shared.onManualShortcutChanged = { [weak self] shortcut in
            self?.automaticLayoutCorrection.updateManualShortcut(shortcut)
        }
        LayoutHotKeyCoordinator.shared.start(
            manualAction: { [weak self] in
                MainActor.assumeIsolated { self?.correctLayoutOrUndo() }
            },
            disableAction: { [weak self] in
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

        // Accessibility is requested only after the onboarding explanation and
        // an explicit user action.
#if DEBUG
        let qaEnvironment = ProcessInfo.processInfo.environment
        if qaEnvironment["NECLIP_UI_TEST_REGULAR"] == "1" || qaEnvironment["NECLIP_UI_TEST_TAB"] != nil {
            // QA builds temporarily behave like a regular app so automated
            // accessibility inspection can address the panel by bundle ID.
            NSApp.setActivationPolicy(.regular)
        }
        if qaEnvironment["NECLIP_UI_TEST_SKIP_ONBOARDING"] != "1" {
            startMonitorAroundOnboarding()
        } else {
            monitor.start()
        }
        if let tab = qaEnvironment["NECLIP_UI_TEST_TAB"] {
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
        NotificationCenter.default.removeObserver(self)
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        automaticLayoutCorrection.refreshContext()
        monitor.refreshAuthorization()
        statusBar.refreshAuthorizationState()
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
    }

    @objc private func manualLayoutCorrectionRequested() {
        correctLayoutOrUndo()
    }

    @objc private func disableAutomaticLayoutCorrectionRequested() {
        disableAutomaticLayoutCorrection()
    }

    private func refreshHotKeyWarnings() {
        statusBar.setHotKeyWarnings(fixedHotKeyWarnings + layoutHotKeyWarnings)
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
            self?.statusBar.showLayoutFeedback(undone ? "Исправление отменено" : "Отмена уже недоступна")
        }) {
            return
        }

        manualLayoutCorrection.correctOrUndo { [weak self] result in
            self?.automaticLayoutCorrection.refreshContext()
            let message: String
            switch result {
            case .corrected:
                message = "Раскладка исправлена · \(LayoutHotKeyCoordinator.shared.manualShortcut.displayString) — отменить"
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
