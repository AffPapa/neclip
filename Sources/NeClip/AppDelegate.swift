import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private let monitor = ClipboardMonitor()
    private var hotKeyWarnings: [String] = []
    private let manualLayoutCorrection = ManualLayoutCorrectionService()
    private let automaticLayoutCorrection = AutoLayoutController()

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        // Accessibility is requested only after the onboarding explanation and
        // an explicit user action.
#if DEBUG
        let qaEnvironment = ProcessInfo.processInfo.environment
        if qaEnvironment["NECLIP_UI_TEST_REGULAR"] == "1"
            || qaEnvironment["NECLIP_UI_TEST_TAB"] != nil
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
        if qaEnvironment["NECLIP_UI_TEST_EDITOR"] == "1" {
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
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        SnippetsEditorWindowController.shared.prepareForTermination()
            ? .terminateNow
            : .terminateCancel
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
            self?.statusBar.showLayoutFeedback(undone ? "Исправление отменено" : "Отмена уже недоступна")
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
