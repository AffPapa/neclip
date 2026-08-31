import Foundation

enum LayoutShortcutAction: Sendable {
    case manualCorrection
    case disableAutomaticCorrection
}

enum LayoutShortcutUpdateResult: Equatable, Sendable {
    case applied
    case unchanged
    case rejected(String)

    var message: String? {
        if case .rejected(let message) = self { return message }
        return nil
    }
}

/// Owns only the two layout shortcuts. A replacement is registered before the
/// old object is released or UserDefaults is changed, so a conflict can never
/// silently leave the user without the previously working shortcut. Reset is
/// a two-registration transaction because the two actions may have exchanged
/// their previous defaults.
@MainActor
final class LayoutHotKeyCoordinator {
    static let shared = LayoutHotKeyCoordinator()

    private var manualRegistration: (any HotKeyRegistrationToken)?
    private var disableRegistration: (any HotKeyRegistrationToken)?
    private var manualAction: GlobalHotKey.Action?
    private var disableAction: GlobalHotKey.Action?
    private var nextIdentifier: UInt32 = 100
    private var manualRegistrationFailed = false
    private var disableRegistrationFailed = false
    private var manualFailureMessage: String?
    private var disableFailureMessage: String?
    private let registrationFactory: any HotKeyRegistrationCreating
    private let reloadsPersistedShortcuts: Bool
    private let persistsSettings: Bool

    var onWarningsChanged: (([String]) -> Void)?
    var onManualShortcutChanged: ((ShortcutDescriptor) -> Void)?

    private(set) var manualShortcut: ShortcutDescriptor
    private(set) var disableAutomaticShortcut: ShortcutDescriptor

    init(
        registrationFactory: any HotKeyRegistrationCreating = CarbonHotKeyRegistrationFactory(),
        initialManualShortcut: ShortcutDescriptor? = nil,
        initialDisableAutomaticShortcut: ShortcutDescriptor? = nil,
        persistsSettings: Bool = true
    ) {
        self.registrationFactory = registrationFactory
        reloadsPersistedShortcuts = initialManualShortcut == nil && initialDisableAutomaticShortcut == nil
        self.persistsSettings = persistsSettings
        manualShortcut = initialManualShortcut ?? Settings.manualLayoutShortcut
        disableAutomaticShortcut = initialDisableAutomaticShortcut ?? Settings.disableAutomaticLayoutShortcut
    }

    func start(
        manualAction: @escaping GlobalHotKey.Action,
        disableAction: @escaping GlobalHotKey.Action
    ) {
        self.manualAction = manualAction
        self.disableAction = disableAction
        if reloadsPersistedShortcuts {
            manualShortcut = Settings.manualLayoutShortcut
            disableAutomaticShortcut = Settings.disableAutomaticLayoutShortcut
        }

        do {
            manualRegistration = try makeRegistration(for: manualShortcut, action: manualAction)
            manualRegistrationFailed = false
            manualFailureMessage = nil
        } catch {
            manualRegistration = nil
            manualRegistrationFailed = true
            manualFailureMessage = failureMessage(for: manualShortcut, error: error)
        }
        do {
            disableRegistration = try makeRegistration(for: disableAutomaticShortcut, action: disableAction)
            disableRegistrationFailed = false
            disableFailureMessage = nil
        } catch {
            disableRegistration = nil
            disableRegistrationFailed = true
            disableFailureMessage = failureMessage(for: disableAutomaticShortcut, error: error)
        }
        onManualShortcutChanged?(manualShortcut)
        publishWarnings()
    }

    @discardableResult
    func update(_ action: LayoutShortcutAction, to candidate: ShortcutDescriptor) -> LayoutShortcutUpdateResult {
        if let validation = ShortcutPolicy.validationError(for: candidate) {
            return .rejected(validation)
        }

        let other = action == .manualCorrection ? disableAutomaticShortcut : manualShortcut
        guard candidate != other else {
            return .rejected("Это сочетание уже назначено другому действию NeClip")
        }

        let current = action == .manualCorrection ? manualShortcut : disableAutomaticShortcut
        let registrationFailed = action == .manualCorrection
            ? manualRegistrationFailed
            : disableRegistrationFailed
        if candidate == current, !registrationFailed {
            return .unchanged
        }

        guard let callback = action == .manualCorrection ? manualAction : disableAction else {
            return .rejected("NeClip ещё не готов менять сочетания")
        }
        let replacement: any HotKeyRegistrationToken
        do {
            replacement = try makeRegistration(for: candidate, action: callback)
        } catch {
            return .rejected(failureMessage(for: candidate, error: error))
        }

        switch action {
        case .manualCorrection:
            manualRegistration = replacement
            manualShortcut = candidate
            manualRegistrationFailed = false
            manualFailureMessage = nil
            if persistsSettings { Settings.storeManualLayoutShortcut(candidate) }
            onManualShortcutChanged?(candidate)
        case .disableAutomaticCorrection:
            disableRegistration = replacement
            disableAutomaticShortcut = candidate
            disableRegistrationFailed = false
            disableFailureMessage = nil
            if persistsSettings { Settings.storeDisableAutomaticLayoutShortcut(candidate) }
        }
        publishWarnings()
        return .applied
    }

    func resetToDefaults() -> LayoutShortcutUpdateResult {
        guard let manualAction, let disableAction else {
            return .rejected("NeClip ещё не готов менять сочетания")
        }
        if manualShortcut == .defaultManualLayout,
           disableAutomaticShortcut == .defaultDisableAutomaticLayout,
           !manualRegistrationFailed,
           !disableRegistrationFailed {
            return .unchanged
        }

        let previousManual = manualShortcut
        let previousDisable = disableAutomaticShortcut

        // Release both NeClip-owned chords before registering the pair. This
        // permits a valid cross-assignment to return to its original defaults.
        manualRegistration = nil
        disableRegistration = nil

        var newManual: (any HotKeyRegistrationToken)?
        var newDisable: (any HotKeyRegistrationToken)?
        do {
            newManual = try makeRegistration(for: .defaultManualLayout, action: manualAction)
            newDisable = try makeRegistration(for: .defaultDisableAutomaticLayout, action: disableAction)

            manualRegistration = newManual
            disableRegistration = newDisable
            manualShortcut = .defaultManualLayout
            disableAutomaticShortcut = .defaultDisableAutomaticLayout
            manualRegistrationFailed = false
            disableRegistrationFailed = false
            manualFailureMessage = nil
            disableFailureMessage = nil
            if persistsSettings {
                Settings.storeManualLayoutShortcut(.defaultManualLayout)
                Settings.storeDisableAutomaticLayoutShortcut(.defaultDisableAutomaticLayout)
            }
            onManualShortcutChanged?(.defaultManualLayout)
            publishWarnings()
            return .applied
        } catch {
            let resetMessage = failureMessage(for: nil, error: error)
            newManual = nil
            newDisable = nil

            do {
                manualRegistration = try makeRegistration(for: previousManual, action: manualAction)
                manualRegistrationFailed = false
                manualFailureMessage = nil
            } catch {
                manualRegistration = nil
                manualRegistrationFailed = true
                manualFailureMessage = failureMessage(for: previousManual, error: error)
            }
            do {
                disableRegistration = try makeRegistration(for: previousDisable, action: disableAction)
                disableRegistrationFailed = false
                disableFailureMessage = nil
            } catch {
                disableRegistration = nil
                disableRegistrationFailed = true
                disableFailureMessage = failureMessage(for: previousDisable, error: error)
            }
            manualShortcut = previousManual
            disableAutomaticShortcut = previousDisable
            onManualShortcutChanged?(previousManual)
            publishWarnings()
            return .rejected("Не удалось восстановить стандартные сочетания: \(resetMessage)")
        }
    }

    private func makeRegistration(
        for shortcut: ShortcutDescriptor,
        action: @escaping GlobalHotKey.Action
    ) throws -> any HotKeyRegistrationToken {
        nextIdentifier &+= 1
        return try registrationFactory.makeRegistration(
            shortcut: shortcut,
            identifier: nextIdentifier,
            action: action
        )
    }

    private func failureMessage(for shortcut: ShortcutDescriptor?, error: Error) -> String {
        let chord = shortcut.map { "\($0.displayName) " } ?? ""
        switch error as? GlobalHotKeyRegistrationError {
        case .alreadyRegistered:
            return "\(chord)уже используется macOS или другой программой"
        case .eventHandlerInstallationFailed:
            return "Не удалось подключить обработчик горячих клавиш"
        case .registrationFailed, .missingRegistrationReference:
            return "Не удалось зарегистрировать \(chord.isEmpty ? "горячие клавиши" : chord)"
        case nil:
            return "Не удалось зарегистрировать \(chord.isEmpty ? "горячие клавиши" : chord)"
        }
    }

    private func publishWarnings() {
        var warnings: [String] = []
        if manualRegistrationFailed {
            warnings.append(
                "\(manualFailureMessage ?? "\(manualShortcut.displayName) недоступна") — ручное исправление доступно в меню"
            )
        }
        if disableRegistrationFailed {
            warnings.append(
                "\(disableFailureMessage ?? "\(disableAutomaticShortcut.displayName) недоступна") — автоисправление можно выключить в меню"
            )
        }
        onWarningsChanged?(warnings)
    }
}
