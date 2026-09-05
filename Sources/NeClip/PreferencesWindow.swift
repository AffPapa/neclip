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
            let hosting = NSHostingController(rootView: PreferencesView(
                onClose: { [weak self] in self?.window?.performClose(nil) },
                onEscape: { [weak self] in
                    guard let window = self?.window,
                          Self.allowsEscapeClose(firstResponder: window.firstResponder) else { return }
                    window.performClose(nil)
                }
            ))
            let window = NSWindow(contentViewController: hosting)
            window.title = "\(RuntimeIdentity.displayName) — Настройки"
            window.styleMask = [.titled, .closable, .resizable]
            window.minSize = NSSize(width: 600, height: 500)
            window.setContentSize(NSSize(width: 640, height: 600))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    static func allowsEscapeClose(firstResponder: NSResponder?) -> Bool {
        // Field editors and shortcut recorders own Escape while focused:
        // canceling their input must not also dismiss the settings window.
        !(firstResponder is NSTextView
            || firstResponder is NSTextField
            || firstResponder is ShortcutRecorderButton)
    }
}

private struct NumericPreferenceRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String
    let accessibilityLabel: String

    @State private var text: String
    @FocusState private var isEditing: Bool

    init(
        _ title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String,
        accessibilityLabel: String
    ) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.accessibilityLabel = accessibilityLabel
        _text = State(initialValue: String(value.wrappedValue))
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
            Spacer()
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .accessibilityLabel(accessibilityLabel)
                .help("От \(range.lowerBound) до \(range.upperBound). Enter — применить, Escape — отменить ввод.")
                .focused($isEditing)
                .onSubmit(commitText)
                .onExitCommand {
                    text = String(value)
                    isEditing = false
                }
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .accessibilityLabel("Изменить: \(accessibilityLabel.lowercased())")
        }
        .onChange(of: value) { _, newValue in
            text = String(newValue)
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { commitText() }
        }
    }

    private func commitText() {
        let requested = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)) ?? value
        let normalized = min(range.upperBound, max(range.lowerBound, requested))
        value = normalized
        text = String(normalized)
    }
}

private struct PreferencesView: View {
    let onClose: () -> Void
    let onEscape: () -> Void

    private enum PreferencesTab: Hashable {
        case general
        case shortcuts
        case privacy
        case layout
        case data
    }

    @State private var selectedTab = PreferencesTab.general
    @State private var historyLimit = Settings.historyLimit
    @State private var menuTitleLength = Settings.menuTitleLength
    @State private var maximumTextCaptureKilobytes = Settings.maximumTextCaptureKilobytes
    @State private var clipboardAccess = ClipboardAccess.current
    @State private var captureImages = Settings.captureImages
    @State private var retentionDays = Settings.retentionDays
    @State private var sensitiveRulesText = Settings.sensitiveContentRules.joined(separator: "\n")
    @State private var preferPlainText = Settings.preferPlainText
    @State private var loginItemStatus = SMAppService.mainApp.status
    @State private var excludedApps = Settings.excludedApps
    @State private var axTrusted = PasteService.isAccessibilityTrusted
    @State private var capturePaused = Settings.isCapturePaused
    @State private var automaticLayoutCorrection = Settings.automaticLayoutCorrection
    @State private var rememberLayoutPerApplication = Settings.rememberLayoutPerApplication
    @State private var rememberedApplicationCount = Settings.rememberedApplicationCount
    @State private var fixedApplicationCount = Settings.fixedApplicationCount
    @State private var historyShortcut = Settings.historyShortcut
    @State private var snippetsShortcut = Settings.snippetsShortcut
    @State private var sequentialPasteShortcut = Settings.sequentialPasteShortcut
    @State private var manualLayoutShortcut = Settings.manualLayoutShortcut
    @State private var disableAutomaticLayoutShortcut = Settings.disableAutomaticLayoutShortcut
    @State private var layoutExcludedApps = Settings.layoutExcludedApps
    @State private var canListenToInput = LayoutPermissions.canListen
    @State private var deleteAllConfirmation = false
    @State private var clearHistoryConfirmation = false
    @State private var clearHistoryOnQuit = Settings.clearHistoryOnQuit
    @State private var feedback: String?
    @State private var dataOperationRunning = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Раздел настроек", selection: $selectedTab) {
                Text("Основные").tag(PreferencesTab.general)
                Text("Клавиши").tag(PreferencesTab.shortcuts)
                Text("Приватность").tag(PreferencesTab.privacy)
                Text("Раскладка").tag(PreferencesTab.layout)
                Text("Данные").tag(PreferencesTab.data)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(14)
            Divider()
            selectedTabContent
            if feedback != nil || dataOperationRunning {
                Divider()
                HStack {
                    if dataOperationRunning {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Операция с локальными данными выполняется")
                    }
                    Image(systemName: "info.circle")
                    Text(dataOperationRunning ? "Выполняется…" : (feedback ?? ""))
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            Divider()
            HStack {
                Spacer()
                Button("Закрыть", action: onClose)
                    .help("Закрыть настройки · ⌘W. NeClip продолжит работать в строке меню.")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 600, minHeight: 500)
        .onExitCommand(perform: onEscape)
        .onAppear { loginItemStatus = SMAppService.mainApp.status }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItemStatus = SMAppService.mainApp.status
            axTrusted = PasteService.isAccessibilityTrusted
            clipboardAccess = ClipboardAccess.current
            capturePaused = Settings.isCapturePaused
            canListenToInput = LayoutPermissions.canListen
            automaticLayoutCorrection = Settings.automaticLayoutCorrection
        }
        .onReceive(NotificationCenter.default.publisher(for: .neClipHotKeysDidChange)) { _ in
            historyShortcut = HotKeyCoordinator.shared.shortcut(for: .history)
            snippetsShortcut = HotKeyCoordinator.shared.shortcut(for: .snippets)
            sequentialPasteShortcut = HotKeyCoordinator.shared.shortcut(for: .sequentialPaste)
            manualLayoutShortcut = HotKeyCoordinator.shared.shortcut(for: .manualCorrection)
            disableAutomaticLayoutShortcut = HotKeyCoordinator.shared.shortcut(for: .disableAutomaticCorrection)
        }
        .onReceive(NotificationCenter.default.publisher(for: .neClipCaptureControlsDidChange)) { _ in
            capturePaused = Settings.isCapturePaused
            excludedApps = Settings.excludedApps
            captureImages = Settings.captureImages
        }
        .onReceive(NotificationCenter.default.publisher(for: .neClipLayoutSettingsDidChange)) { _ in
            automaticLayoutCorrection = Settings.automaticLayoutCorrection
            layoutExcludedApps = Settings.layoutExcludedApps
            rememberLayoutPerApplication = Settings.rememberLayoutPerApplication
        }
        .onReceive(NotificationCenter.default.publisher(for: .neClipApplicationLayoutMemoryDidChange)) { _ in
            rememberedApplicationCount = Settings.rememberedApplicationCount
            fixedApplicationCount = Settings.fixedApplicationCount
        }
        .onChange(of: feedback) { _, message in
            guard let message else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                if PreferencesFeedbackPolicy.shouldExpire(
                    current: feedback, expected: message, operationRunning: dataOperationRunning
                ) { feedback = nil }
            }
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

    @ViewBuilder
    private var selectedTabContent: some View {
        switch selectedTab {
        case .general: generalTab
        case .shortcuts: shortcutsTab
        case .privacy: privacyTab
        case .layout: layoutTab
        case .data: dataTab
        }
    }

    private var generalTab: some View {
        Form {
            Section("История") {
                NumericPreferenceRow(
                    "Размер истории",
                    value: $historyLimit,
                    range: 10...1_000,
                    step: 10,
                    unit: "элементов",
                    accessibilityLabel: "Количество элементов истории"
                )
                    .onChange(of: historyLimit) { _, value in applyHistoryLimit(value) }
                NumericPreferenceRow(
                    "Длина строки в меню",
                    value: $menuTitleLength,
                    range: MenuTitleFormatter.validLengthRange,
                    step: 1,
                    unit: "символов",
                    accessibilityLabel: "Количество символов в строке меню"
                )
                    .onChange(of: menuTitleLength) { _, value in applyMenuTitleLength(value) }
                NumericPreferenceRow(
                    "Размер текста одной записи",
                    value: $maximumTextCaptureKilobytes,
                    range: Settings.maximumTextCaptureKilobytesRange,
                    step: 64,
                    unit: "КБ",
                    accessibilityLabel: "Максимальный размер текста одной записи"
                )
                    .onChange(of: maximumTextCaptureKilobytes) { _, value in
                        Settings.maximumTextCaptureKilobytes = value
                    }
                Text("Число можно ввести или изменить стрелками. Полный текст записи не сокращается: слишком большой новый текст просто не попадёт в историю.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                if retentionDays > 0 {
                    Text("Срок проверяется при запуске, новом копировании и изменении лимитов. На паузе очистка по сроку откладывается.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Очищать незакреплённую историю при выходе", isOn: $clearHistoryOnQuit)
                    .onChange(of: clearHistoryOnQuit) { _, value in Settings.clearHistoryOnQuit = value }

            }

            Section("Вставка") {
                Toggle("По умолчанию вставлять без форматирования", isOn: $preferPlainText)
                    .onChange(of: preferPlainText) { _, value in Settings.preferPlainText = value }
                Text("При выборе мышью: ⌘ — только скопировать. Для истории: ⇧ — без форматирования, ⌥ — изменить режим форматирования, ⌃ — исправить раскладку текста.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Последовательная вставка идёт по последним 50 элементам истории и автоматически сбрасывается через 30 секунд.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Система") {
                let login = LoginItemPresentation(status: loginItemStatus)
                Toggle("Запускать при входе в систему", isOn: Binding(
                    get: { login.isRequested },
                    set: { enabled in updateLaunchAtLogin(enabled) }
                ))
                if let detail = login.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if login.needsApproval {
                    Button("Открыть объекты входа macOS…") {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutsTab: some View {
        Form {
            Section("Открытие и вставка") {
                shortcutRow(
                    "Открыть историю",
                    action: .history,
                    shortcut: historyShortcut,
                    accessibilityLabel: "Сочетание для открытия истории",
                    onCandidate: { applyShortcut(.history, candidate: $0) }
                )
                shortcutRow(
                    "Открыть папки сниппетов",
                    action: .snippets,
                    shortcut: snippetsShortcut,
                    accessibilityLabel: "Сочетание для открытия папок сниппетов",
                    onCandidate: { applyShortcut(.snippets, candidate: $0) }
                )
                shortcutRow(
                    "Вставить следующий элемент",
                    action: .sequentialPaste,
                    shortcut: sequentialPasteShortcut,
                    accessibilityLabel: "Сочетание для последовательной вставки",
                    onCandidate: { applyShortcut(.sequentialPaste, candidate: $0) }
                )
            }

            Section("Исправление раскладки") {
                shortcutRow(
                    "Исправить выделение или последнее слово",
                    action: .manualCorrection,
                    shortcut: manualLayoutShortcut,
                    accessibilityLabel: "Сочетание для ручного исправления раскладки",
                    onCandidate: { applyShortcut(.manualCorrection, candidate: $0) }
                )
                shortcutRow(
                    "Быстро выключить автоисправление",
                    action: .disableAutomaticCorrection,
                    shortcut: disableAutomaticLayoutShortcut,
                    accessibilityLabel: "Сочетание для выключения автоматического исправления",
                    onCandidate: { applyShortcut(.disableAutomaticCorrection, candidate: $0) }
                )
            }

            Section {
                Button("Вернуть стандартные сочетания") { resetAllShortcuts() }
                Text("Нажмите сочетание в рамке и введите новое. Escape отменяет. NeClip не применит занятое сочетание и сохранит предыдущее.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var privacyTab: some View {
        Form {
            Section("Доступ") {
                HStack(alignment: .top) {
                    Image(systemName: clipboardPermissionSymbol)
                        .foregroundStyle(clipboardPermissionColor)
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
                HStack {
                    Image(systemName: axTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(axTrusted ? .green : .orange)
                    Text(axTrusted ? "Автовставка разрешена" : "Без Универсального доступа NeClip только копирует")
                    Spacer()
                    if !axTrusted {
                        Button("Разрешить…") { PasteService.requestAccessibility() }
                    }
                }
                if !axTrusted {
                    Text("Если NeClip уже есть в списке macOS, просто включите переключатель. Кнопка + не нужна.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Запись истории") {
                HStack {
                    Label(
                        capturePaused ? "Запись приостановлена" : "История записывается",
                        systemImage: capturePaused ? "pause.circle.fill" : "checkmark.circle.fill"
                    )
                    .foregroundStyle(capturePaused ? .orange : .green)
                    Spacer()
                    Button(capturePaused ? "Возобновить" : "Пауза на 15 минут") {
                        if capturePaused {
                            Settings.resumeCapture()
                            feedback = Settings.captureResumeFailureMessage ?? "Запись возобновлена"
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
                Button("Объединить следующий текст с предыдущим") {
                    Settings.appendNextCopy = true
                    feedback = "Следующий допустимый текст будет добавлен к предыдущему"
                }
                DisclosureGroup("Не сохранять текст с указанными фразами") {
                    let rules = SensitiveRulesPresentation(text: sensitiveRulesText)
                    TextEditor(text: $sensitiveRulesText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 76)
                        .onChange(of: sensitiveRulesText) { _, value in
                            Settings.sensitiveContentRules = value.components(separatedBy: .newlines)
                        }
                    Text("Активно правил: \(rules.activeCount) из \(SensitiveContentPolicy.maximumRuleCount). Одна фраза на строку, до \(SensitiveContentPolicy.maximumRuleLength) символов.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let warning = rules.warning {
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section("Не записывать из приложений") {
                Text("Парольные менеджеры защищены всегда; остальные приложения можно добавить или быстро исключить из меню NeClip.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                List {
                    ForEach(excludedApps, id: \.self) { bundleID in
                        ExcludedApplicationRow(
                            bundleIdentifier: bundleID,
                            isProtected: SensitiveApplicationPolicy.protects(bundleID)
                        ) {
                            excludedApps.removeAll { $0 == bundleID }
                            Settings.excludedApps = excludedApps
                        }
                    }
                }
                .frame(height: 145)
                Button("Добавить приложение…", action: addApp)
            }
        }
        .formStyle(.grouped)
    }

    private var layoutTab: some View {
        Form {
            Section("Раскладка приложений") {
                Toggle("Запоминать последнюю раскладку для каждого приложения", isOn: $rememberLayoutPerApplication)
                    .onChange(of: rememberLayoutPerApplication) { _, value in
                        Settings.rememberLayoutPerApplication = value
                    }
                HStack {
                    Text("Запомнено автоматически: \(rememberedApplicationCount)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Очистить память") {
                        Settings.clearRememberedApplicationLayouts()
                        feedback = "Запомненные раскладки сброшены"
                    }
                    .disabled(rememberedApplicationCount == 0)
                }
                HStack {
                    Text("Закреплено вручную: \(fixedApplicationCount)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Снять все") {
                        Settings.clearFixedApplicationLayouts()
                        feedback = "Закреплённые раскладки сброшены"
                    }
                    .disabled(fixedApplicationCount == 0)
                }
                Text("Закрепить текущую раскладку можно в меню NeClip → «Управление» → «Раскладка». Она будет выбрана при следующем открытии этого приложения.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Следит только за активным приложением и выбранной системной раскладкой. Текст и нажатия клавиш не читаются; «Мониторинг ввода» не нужен.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Автоматическое исправление") {
                Toggle("Автоматически исправлять (бета)", isOn: Binding(
                    get: { automaticLayoutCorrection },
                    set: { updateAutomaticLayoutCorrection($0) }
                ))
                Text("Срабатывает только по пробелу и только при высокой уверенности. Текст обрабатывается локально, не сохраняется и не отправляется в сеть.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Разрешения автоматического режима") {
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
            }

            Section("Исключения приложений") {
                DisclosureGroup("Не менять раскладку автоматически в приложениях") {
                    List {
                        ForEach(layoutExcludedApps, id: \.self) { bundleID in
                            ExcludedApplicationRow(bundleIdentifier: bundleID, isProtected: false) {
                                layoutExcludedApps.removeAll { $0 == bundleID }
                                Settings.layoutExcludedApps = layoutExcludedApps
                            }
                        }
                    }
                    .frame(height: 95)
                    Button("Добавить приложение…", action: addLayoutExcludedApp)
                    Text("Список применяется к автоисправлению и запоминанию раскладки. Пароли, терминалы, IDE и удалённые рабочие столы дополнительно защищены от автоисправления всегда.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var dataTab: some View {
        Form {
            Section("Перенос сниппетов") {
                HStack {
                    Button("Экспортировать сниппеты…", action: exportSnippets)
                    Button("Импортировать сниппеты…", action: importSnippets)
                }
                Text("Переносится только локальная библиотека сниппетов — без истории и статистики использования.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Готовые примеры") {
                Button("Восстановить готовые сниппеты") { restoreStarterSnippets() }
            }
            Section("Очистка") {
                Button("Очистить историю…", role: .destructive) {
                    clearHistoryConfirmation = true
                }
                Button("Удалить всю историю и сниппеты…", role: .destructive) {
                    deleteAllConfirmation = true
                }
                Text("Перед удалением NeClip попросит подтверждение. Экспортируйте важные сниппеты заранее.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .disabled(dataOperationRunning)
    }

    @ViewBuilder
    private func shortcutRow(
        _ title: String,
        action: NeClipShortcutAction,
        shortcut: ShortcutDescriptor,
        accessibilityLabel: String,
        onCandidate: @escaping @MainActor (ShortcutDescriptor) -> Void
    ) -> some View {
        LabeledContent(title) {
            ShortcutRecorder(
                shortcut: shortcut,
                accessibilityLabel: accessibilityLabel,
                onCandidate: onCandidate
            )
            .frame(width: 126, height: 28)
            Button {
                applyShortcut(action, candidate: action.defaultShortcut)
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(shortcut == action.defaultShortcut)
            .help("Вернуть \(action.defaultShortcut.displayString)")
            .accessibilityLabel("Вернуть стандартное сочетание: \(title.lowercased())")
        }
    }

    private var clipboardAccessTitle: String {
        switch clipboardAccess {
        case .unrestricted, .allowed: "История буфера разрешена"
        case .needsChoice: "macOS может спрашивать доступ"
        case .denied: "История буфера заблокирована"
        }
    }

    private var clipboardPermissionSymbol: String {
        switch clipboardAccess {
        case .unrestricted, .allowed: "checkmark.shield.fill"
        case .needsChoice: "questionmark.diamond.fill"
        case .denied: "exclamationmark.shield.fill"
        }
    }

    private var clipboardPermissionColor: Color {
        switch clipboardAccess {
        case .unrestricted, .allowed: .green
        case .needsChoice, .denied: .orange
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
            feedback = "Не удалось изменить запуск при входе"
        }
        loginItemStatus = SMAppService.mainApp.status
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

    private func applyShortcut(_ action: NeClipShortcutAction, candidate: ShortcutDescriptor) {
        let result = HotKeyCoordinator.shared.update(action, to: candidate)
        refreshShortcutState()
        feedback = result.message ?? "Сочетание изменено: \(candidate.displayString)"
    }

    private func resetAllShortcuts() {
        let result = HotKeyCoordinator.shared.resetToDefaults()
        refreshShortcutState()
        feedback = result.message ?? "Стандартные сочетания восстановлены"
    }

    private func refreshShortcutState() {
        historyShortcut = HotKeyCoordinator.shared.shortcut(for: .history)
        snippetsShortcut = HotKeyCoordinator.shared.shortcut(for: .snippets)
        sequentialPasteShortcut = HotKeyCoordinator.shared.shortcut(for: .sequentialPaste)
        manualLayoutShortcut = HotKeyCoordinator.shared.shortcut(for: .manualCorrection)
        disableAutomaticLayoutShortcut = HotKeyCoordinator.shared.shortcut(for: .disableAutomaticCorrection)
    }

    private func applyHistoryLimit(_ requested: Int) {
        let normalized = min(1_000, max(10, requested))
        if historyLimit != normalized {
            historyLimit = normalized
            return
        }
        Settings.historyLimit = normalized
        DispatchQueue.global(qos: .utility).async {
            do {
                try Storage.shared.trimToLimits()
            } catch {
                DispatchQueue.main.async { feedback = "Не удалось применить новый лимит" }
            }
        }
    }

    private func applyMenuTitleLength(_ requested: Int) {
        let normalized = MenuTitleFormatter.normalizedLimit(requested)
        if menuTitleLength != normalized {
            menuTitleLength = normalized
            return
        }
        Settings.menuTitleLength = normalized
        feedback = "В меню будет показано до \(normalized) символов"
    }

    private func clearHistory(includePinned: Bool) {
        runDataOperation(requiresCaptureBarrier: true) {
            do {
                try Storage.shared.clearHistory(includePinned: includePinned)
                do { try Storage.shared.vacuum() }
                catch { return "История очищена. Не удалось освободить неиспользуемое место в файле базы." }
                return "История очищена"
            } catch {
                return "Не удалось очистить историю"
            }
        }
    }

    private func deleteAllData() {
        runDataOperation(requiresCaptureBarrier: true) {
            do {
                try Storage.shared.deleteAllUserData()
                do { try Storage.shared.vacuum() }
                catch { return "История и сниппеты удалены. Не удалось освободить неиспользуемое место в файле базы." }
                return "История, сниппеты и их папки удалены"
            } catch {
                return "Не удалось удалить все данные"
            }
        }
    }

    private func restoreStarterSnippets() {
        runDataOperation {
            do {
                try Storage.shared.installStarterSnippetsIfNeeded(force: true)
                return "Готовые сниппеты восстановлены"
            } catch {
                return "Не удалось восстановить сниппеты"
            }
        }
    }

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "NeClip Snippets.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runDataOperation {
            do {
                try Storage.shared.exportSnippetData().write(to: url, options: .atomic)
                return "Сниппеты экспортированы"
            } catch {
                return "Не удалось экспортировать сниппеты: \(error.localizedDescription)"
            }
        }
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        runDataOperation {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
                guard let fileSize = resourceValues.fileSize,
                      fileSize > 0,
                      fileSize <= Storage.maximumSnippetImportBytes else {
                    throw SnippetTransferError.fileTooLarge
                }
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let count = try Storage.shared.importSnippetData(data)
                return count == 0 ? "Новых сниппетов нет" : "Добавлено сниппетов: \(count)"
            } catch {
                return error.localizedDescription
            }
        }
    }

    private func runDataOperation(
        requiresCaptureBarrier: Bool = false,
        _ operation: @escaping @Sendable () -> String
    ) {
        guard !dataOperationRunning else { return }
        dataOperationRunning = true
        feedback = "Выполняется…"
        Task {
            if requiresCaptureBarrier {
                do { feedback = try await HistoryCleanupCoordinator.shared.run(operation) }
                catch { feedback = error.localizedDescription }
            } else {
                feedback = await Task.detached(priority: .utility, operation: operation).value
            }
            dataOperationRunning = false
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
           let identifier = bundle.bundleIdentifier {
            switch ApplicationExclusionPolicy.adding(identifier, to: layoutExcludedApps) {
            case .added(let updated):
                Settings.layoutExcludedApps = updated
                layoutExcludedApps = Settings.layoutExcludedApps
                feedback = "Приложение добавлено в исключения раскладки"
            case .alreadyExcluded:
                feedback = "Приложение уже есть в исключениях раскладки"
            case .invalidIdentifier:
                feedback = "Не удалось определить идентификатор приложения"
            }
        }
    }
}

private struct ExcludedApplicationRow: View {
    let bundleIdentifier: String
    let isProtected: Bool
    let remove: () -> Void

    private var metadata: AppMetadata {
        AppMetadataStore.shared.metadata(for: bundleIdentifier)
    }

    private var displayName: String {
        SensitiveApplicationPolicy.displayName(for: bundleIdentifier) ?? metadata.name
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: metadata.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                Text(bundleIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isProtected {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(displayName) защищено от записи всегда")
            } else {
                Button(action: remove) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Удалить \(displayName) из исключений")
            }
        }
    }
}
