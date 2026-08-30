import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController!
    private let monitor = ClipboardMonitor()
    private var mainHotKey: GlobalHotKey?
    private var snippetsHotKey: GlobalHotKey?
    private var layoutHotKey: GlobalHotKey?
    private let manualLayoutCorrection = ManualLayoutCorrectionService()
    private let automaticLayoutCorrection = AutoLayoutController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
        DispatchQueue.global(qos: .utility).async {
            try? Storage.shared.installStarterSnippetsIfNeeded(force: false)
        }

        // Native global shortcuts keep the app dependency-light. Handlers are
        // delivered by the application event target on the main run loop.
        mainHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey | shiftKey),
            identifier: 1
        ) { [weak self] in
            MainActor.assumeIsolated { self?.statusBar.showHistory() }
        }

        snippetsHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_B),
            modifiers: UInt32(cmdKey | shiftKey),
            identifier: 2
        ) { [weak self] in
            MainActor.assumeIsolated { self?.statusBar.showSnippets() }
        }

        // A normal chord works without global key monitoring. Repeating it
        // immediately after a correction performs a validated undo.
        layoutHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_L),
            modifiers: UInt32(optionKey | shiftKey),
            identifier: 3
        ) { [weak self] in
            MainActor.assumeIsolated { self?.correctLayoutOrUndo() }
        }

        var hotKeyWarnings: [String] = []
        if mainHotKey == nil {
            hotKeyWarnings.append("⌘⇧V занята — история доступна через значок NeClip")
        }
        if snippetsHotKey == nil {
            hotKeyWarnings.append("⌘⇧B занята — сниппеты доступны в меню NeClip")
        }
        if layoutHotKey == nil {
            hotKeyWarnings.append("⌥⇧L занята — исправление доступно в разделе «Раскладка»")
        }
        statusBar.setHotKeyWarnings(hotKeyWarnings)

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
                message = "Раскладка исправлена · ⌥⇧L — отменить"
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
