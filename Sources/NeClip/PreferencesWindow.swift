import AppKit
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class PreferencesWindowController {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: PreferencesView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "NeClip — Настройки"
            window.styleMask = [.titled, .closable, .resizable]
            window.minSize = NSSize(width: 500, height: 620)
            window.setContentSize(NSSize(width: 520, height: 720))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct PreferencesView: View {
    @State private var historyLimit = Settings.historyLimit
    @State private var menuTitleLengthText = String(Settings.menuTitleLength)
    @State private var clipboardAccess = ClipboardAccess.current
    @State private var showPreviews = Settings.showImagePreviews
    @State private var captureImages = Settings.captureImages
    @State private var retentionDays = Settings.retentionDays
    @State private var sensitiveRulesText = Settings.sensitiveContentRules.joined(separator: "\n")
    @State private var preferPlainText = Settings.preferPlainText
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var excludedApps = Settings.excludedApps
    @State private var axTrusted = PasteService.isAccessibilityTrusted
    @State private var capturePaused = Settings.isCapturePaused
    @State private var automaticLayoutCorrection = Settings.automaticLayoutCorrection
    @State private var manualLayoutShortcut = Settings.manualLayoutShortcut
    @State private var disableAutomaticLayoutShortcut = Settings.disableAutomaticLayoutShortcut
    @State private var layoutExcludedApps = Settings.layoutExcludedApps
    @State private var canListenToInput = LayoutPermissions.canListen
    @State private var deleteAllConfirmation = false
    @State private var clearHistoryConfirmation = false
    @State private var feedback: String?
    @FocusState private var menuTitleLengthFocused: Bool

    var body: some View {
        Form {
            Section("Доступ к буферу") {
                HStack(alignment: .top) {
                    Image(systemName: clipboardAccess == .denied
                        ? "exclamationmark.shield.fill"
                        : "checkmark.shield.fill")
                        .foregroundStyle(clipboardAccess == .denied ? .orange : .green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(clipboardAccessTitle)
                        Text(clipboardAccessDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if clipboardAccess == .denied || clipboardAccess == .needsChoice {
                        Button("Открыть…") { ClipboardAccess.openPrivacySettings() }
                    }
                }
            }

            Section("История") {
                Stepper("Хранить до \(historyLimit) элементов", value: $historyLimit, in: 10...1000, step: 10)
                    .onChange(of: historyLimit) { _, value in applyHistoryLimit(value) }
                HStack {
                    Text("Показывать в меню до")
                    Spacer()
                    TextField("64", text: $menuTitleLengthText)
                        .frame(width: 52)
                        .multilineTextAlignment(.trailing)
                        .focused($menuTitleLengthFocused)
                        .onSubmit(commitMenuTitleLength)
                        .onChange(of: menuTitleLengthText) { _, value in
                            if let parsed = Int(value), MenuTitleFormatter.validLengthRange.contains(parsed) {
                                Settings.menuTitleLength = parsed
                            }
                        }
                    Text("символов")
                        .foregroundStyle(.secondary)
                }
                .onChange(of: menuTitleLengthFocused) { _, focused in
                    if !focused { commitMenuTitleLength() }
                }
                Text("Допустимо 16–96. Длинные строки заканчиваются многоточием, полный текст сохраняется.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Показывать превью изображений", isOn: $showPreviews)
                    .onChange(of: showPreviews) { _, value in Settings.showImagePreviews = value }
                Toggle("Сохранять изображения", isOn: $captureImages)
                    .onChange(of: captureImages) { _, value in Settings.captureImages = value }
                Picker("Удалять незакреплённое", selection: $retentionDays) {
                    Text("Только по лимиту").tag(0)
                    Text("Через 1 день").tag(1)
                    Text("Через 7 дней").tag(7)
                    Text("Через 30 дней").tag(30)
                    Text("Через 90 дней").tag(90)
                }
                .onChange(of: retentionDays) { _, value in
                    Settings.retentionDays = value
                    DispatchQueue.global(qos: .utility).async { try? Storage.shared.trimToLimits() }
                }

                DisclosureGroup("Не сохранять текст с указанными фразами") {
                    TextEditor(text: $sensitiveRulesText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 76)
                        .onChange(of: sensitiveRulesText) { _, value in
                            Settings.sensitiveContentRules = value.components(separatedBy: .newlines)
                        }
                    Text("Одна фраза на строку. Проверка локальная, без регулярных выражений; до 50 правил.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label(
                        capturePaused ? "Запись истории приостановлена" : "История записывается",
                        systemImage: capturePaused ? "pause.circle.fill" : "checkmark.circle.fill"
                    )
                    .foregroundStyle(capturePaused ? .orange : .green)
                    Spacer()
                    Button(capturePaused ? "Возобновить" : "Пауза на 15 минут") {
                        if capturePaused {
                            Settings.resumeCapture()
                        } else {
                            Settings.pauseFor15Minutes()
                        }
                        capturePaused = Settings.isCapturePaused
                    }
                }

                Button("Не сохранять следующее копирование") {
                    Settings.ignoreNextCopy = true
                    feedback = "Следующее копирование будет пропущено"
                }
            }

            Section("Вставка") {
                Toggle("По умолчанию вставлять без форматирования", isOn: $preferPlainText)
                    .onChange(of: preferPlainText) { _, value in Settings.preferPlainText = value }
                Text("Удерживайте ⌥ при выборе, чтобы временно изменить режим.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Image(systemName: axTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(axTrusted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(axTrusted ? "Автовставка разрешена" : "Без разрешения NeClip только копирует")
                        if !axTrusted {
                            Text("Можно вставить вручную клавишами ⌘V.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if !axTrusted {
                        Button("Разрешить…") { PasteService.requestAccessibility() }
                    }
                }
            }

            Section("Раскладка") {
                Toggle("Автоматически исправлять (бета)", isOn: Binding(
                    get: { automaticLayoutCorrection },
                    set: { updateAutomaticLayoutCorrection($0) }
                ))
                Text("Только по пробелу и только когда NeClip уверен. Набираемый текст обрабатывается локально, не сохраняется и не отправляется в сеть.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Исправить выделение или последнее слово") {
                    ShortcutRecorder(
                        shortcut: manualLayoutShortcut,
                        accessibilityLabel: "Сочетание для ручного исправления раскладки",
                        onCandidate: applyManualLayoutShortcut
                    )
                    .frame(width: 126, height: 28)
                }
                LabeledContent("Быстро выключить автоисправление") {
                    ShortcutRecorder(
                        shortcut: disableAutomaticLayoutShortcut,
                        accessibilityLabel: "Сочетание для выключения автоматического исправления",
                        onCandidate: applyDisableAutomaticLayoutShortcut
                    )
                    .frame(width: 126, height: 28)
                }
                Button("Сбросить сочетания") { resetLayoutShortcuts() }
                Text("Нажмите сочетание в рамке, затем введите новое. Escape отменяет. Клавиша выключения никогда не включает мониторинг ввода.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                permissionRow(
                    title: "Мониторинг ввода",
                    granted: canListenToInput,
                    requiredFor: "для автоматического режима",
                    buttonTitle: "Открыть «Мониторинг ввода»…",
                    openSettings: { openPrivacyPane("Privacy_ListenEvent") }
                )
                permissionRow(
                    title: "Универсальный доступ",
                    granted: axTrusted,
                    requiredFor: "для безопасной замены",
                    buttonTitle: "Открыть «Универсальный доступ»…",
                    openSettings: { openPrivacyPane("Privacy_Accessibility") }
                )
                if !axTrusted {
                    Text("NeClip уже включён? Выключите и включите его снова. Нажимать + не нужно.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup("Не исправлять автоматически в приложениях") {
                    List {
                        ForEach(layoutExcludedApps, id: \.self) { bundleID in
                            ExcludedApplicationRow(bundleIdentifier: bundleID) {
                                layoutExcludedApps.removeAll { $0 == bundleID }
                                Settings.layoutExcludedApps = layoutExcludedApps
                            }
                        }
                    }
                    .frame(height: 95)
                    Button("Добавить приложение…", action: addLayoutExcludedApp)
                    Text("Пароли, терминалы, IDE и удалённые рабочие столы заблокированы всегда.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Система") {
                Toggle("Запускать при входе в систему", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in updateLaunchAtLogin(enabled) }
            }

            Section("Исключённые приложения") {
                Text("Скопированное в этих приложениях не попадает в историю.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                List {
                    ForEach(excludedApps, id: \.self) { bundleID in
                        ExcludedApplicationRow(bundleIdentifier: bundleID) {
                            excludedApps.removeAll { $0 == bundleID }
                            Settings.excludedApps = excludedApps
                        }
                    }
                }
                .frame(height: 125)

                Button("Добавить приложение…", action: addApp)
            }

            Section("Локальные данные") {
                HStack {
                    Button("Восстановить готовые сниппеты") { restoreStarterSnippets() }
                    Spacer()
                    Button("Очистить историю…", role: .destructive) {
                        clearHistoryConfirmation = true
                    }
                }
                Button("Удалить всю историю и сниппеты…", role: .destructive) {
                    deleteAllConfirmation = true
                }
                HStack {
                    Button("Экспортировать сниппеты…", action: exportSnippets)
                    Button("Импортировать сниппеты…", action: importSnippets)
                }
                Text("Переносится только локальная библиотека сниппетов — без истории и статистики использования.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 580)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            axTrusted = PasteService.isAccessibilityTrusted
            clipboardAccess = ClipboardAccess.current
            capturePaused = Settings.isCapturePaused
            canListenToInput = LayoutPermissions.canListen
            automaticLayoutCorrection = Settings.automaticLayoutCorrection
        }
        .onReceive(NotificationCenter.default.publisher(for: .neClipLayoutHotKeysDidChange)) { _ in
            manualLayoutShortcut = LayoutHotKeyCoordinator.shared.manualShortcut
            disableAutomaticLayoutShortcut = LayoutHotKeyCoordinator.shared.disableAutomaticShortcut
        }
        .alert("Очистить историю?", isPresented: $clearHistoryConfirmation) {
            Button("Удалить незакреплённое", role: .destructive) { clearHistory(includePinned: false) }
            Button("Удалить всё, включая закреплённое", role: .destructive) { clearHistory(includePinned: true) }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Сниппеты останутся на месте.")
        }
        .alert("Удалить историю и сниппеты?", isPresented: $deleteAllConfirmation) {
            Button("Удалить историю и сниппеты", role: .destructive, action: deleteAllData)
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }

    private var clipboardAccessTitle: String {
        switch clipboardAccess {
        case .unrestricted, .allowed: "История буфера разрешена"
        case .needsChoice: "macOS может спрашивать доступ"
        case .denied: "История буфера заблокирована"
        }
    }

    private var clipboardAccessDetail: String {
        switch clipboardAccess {
        case .unrestricted, .allowed:
            "Новые копирования могут сохраняться в локальную историю."
        case .needsChoice:
            "В «Конфиденциальность и безопасность» → «Буфер обмена» выберите для NeClip «Всегда разрешать»."
        case .denied:
            "NeClip не читает содержимое в фоне. Разрешите доступ в разделе «Буфер обмена», затем вернитесь."
        }
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            feedback = "Не удалось изменить запуск при входе"
        }
    }

    @ViewBuilder
    private func permissionRow(
        title: String,
        granted: Bool,
        requiredFor: String,
        buttonTitle: String,
        openSettings: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(title, systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(granted ? .green : .orange)
            Spacer()
            Text(granted ? "Разрешено" : requiredFor)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !granted {
                Button(buttonTitle, action: openSettings)
            }
        }
    }

    private func openPrivacyPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private func updateAutomaticLayoutCorrection(_ enabled: Bool) {
        if enabled {
            guard KeyboardLayoutService.shared.layoutPair() != nil else {
                automaticLayoutCorrection = false
                Settings.automaticLayoutCorrection = false
                feedback = "Добавьте английскую и русскую раскладки в настройках macOS"
                return
            }
            guard LayoutPermissions.requestForAutomaticCorrection() else {
                automaticLayoutCorrection = false
                Settings.automaticLayoutCorrection = false
                feedback = "Разрешите Мониторинг ввода и Универсальный доступ, затем включите снова"
                return
            }
        }
        automaticLayoutCorrection = enabled
        Settings.automaticLayoutCorrection = enabled
        feedback = enabled ? "Автоисправление включено: только по пробелу" : "Автоисправление выключено"
    }

    private func applyManualLayoutShortcut(_ candidate: ShortcutDescriptor) {
        let result = LayoutHotKeyCoordinator.shared.update(.manualCorrection, to: candidate)
        manualLayoutShortcut = LayoutHotKeyCoordinator.shared.manualShortcut
        feedback = result.message ?? "Сочетание ручного исправления: \(manualLayoutShortcut.displayString)"
    }

    private func applyDisableAutomaticLayoutShortcut(_ candidate: ShortcutDescriptor) {
        let result = LayoutHotKeyCoordinator.shared.update(.disableAutomaticCorrection, to: candidate)
        disableAutomaticLayoutShortcut = LayoutHotKeyCoordinator.shared.disableAutomaticShortcut
        feedback = result.message ?? "Сочетание выключения: \(disableAutomaticLayoutShortcut.displayString)"
    }

    private func resetLayoutShortcuts() {
        let result = LayoutHotKeyCoordinator.shared.resetToDefaults()
        manualLayoutShortcut = LayoutHotKeyCoordinator.shared.manualShortcut
        disableAutomaticLayoutShortcut = LayoutHotKeyCoordinator.shared.disableAutomaticShortcut
        feedback = result.message ?? "Сочетания восстановлены"
    }

    private func applyHistoryLimit(_ value: Int) {
        Settings.historyLimit = value
        DispatchQueue.global(qos: .utility).async {
            do {
                try Storage.shared.trimToLimits()
            } catch {
                DispatchQueue.main.async { feedback = "Не удалось применить новый лимит" }
            }
        }
    }

    private func commitMenuTitleLength() {
        let requested = Int(menuTitleLengthText) ?? MenuTitleFormatter.defaultLimit
        let normalized = MenuTitleFormatter.normalizedLimit(requested)
        Settings.menuTitleLength = normalized
        menuTitleLengthText = String(normalized)
        feedback = "В меню будет показано до \(normalized) символов"
    }

    private func clearHistory(includePinned: Bool) {
        do {
            try Storage.shared.clearHistory(includePinned: includePinned)
            feedback = "История очищена"
            vacuumInBackground()
        } catch {
            feedback = "Не удалось очистить историю"
        }
    }

    private func deleteAllData() {
        do {
            try Storage.shared.clearHistory(includePinned: true)
            let snippets = try Storage.shared.allSnippets(search: nil, pinnedOnly: false)
            for snippet in snippets {
                if let id = snippet.id {
                    try Storage.shared.deleteSnippet(id: id)
                }
            }
            feedback = "История и сниппеты удалены"
            vacuumInBackground()
        } catch {
            feedback = "Не удалось удалить все данные"
        }
    }

    private func restoreStarterSnippets() {
        do {
            try Storage.shared.installStarterSnippetsIfNeeded(force: true)
            feedback = "Готовые сниппеты восстановлены"
        } catch {
            feedback = "Не удалось восстановить сниппеты"
        }
    }

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "NeClip Snippets.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try Storage.shared.exportSnippetData().write(to: url, options: .atomic)
            feedback = "Сниппеты экспортированы"
        } catch {
            feedback = "Не удалось экспортировать сниппеты"
        }
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let count = try Storage.shared.importSnippetData(Data(contentsOf: url))
            feedback = count == 0 ? "Новых сниппетов нет" : "Добавлено сниппетов: \(count)"
        } catch {
            feedback = error.localizedDescription
        }
    }

    private func vacuumInBackground() {
        DispatchQueue.global(qos: .utility).async {
            try? Storage.shared.vacuum()
        }
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        if panel.runModal() == .OK,
           let url = panel.url,
           let bundle = Bundle(url: url),
           let identifier = bundle.bundleIdentifier,
           !excludedApps.contains(identifier) {
            excludedApps.append(identifier)
            Settings.excludedApps = excludedApps
        }
    }

    private func addLayoutExcludedApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        if panel.runModal() == .OK,
           let url = panel.url,
           let bundle = Bundle(url: url),
           let identifier = bundle.bundleIdentifier,
           !layoutExcludedApps.contains(identifier),
           !LayoutProtectedApplicationPolicy.protectedBundleIDs.contains(identifier) {
            layoutExcludedApps.append(identifier)
            Settings.layoutExcludedApps = layoutExcludedApps
        }
    }
}

private struct ExcludedApplicationRow: View {
    let bundleIdentifier: String
    let remove: () -> Void

    var body: some View {
        let metadata = AppMetadataStore.shared.metadata(for: bundleIdentifier)
        HStack(spacing: 10) {
            Image(nsImage: metadata.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(metadata.name)
                Text(bundleIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(action: remove) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Удалить \(metadata.name) из исключений")
        }
    }
}
