import Foundation

enum NeClipShortcutAction: CaseIterable, Hashable, Sendable {
    case history
    case snippets
    case sequentialPaste
    case manualCorrection
    case disableAutomaticCorrection

    var defaultShortcut: ShortcutDescriptor {
        switch self {
        case .history: .historyDefault
        case .snippets: .snippetsDefault
        case .sequentialPaste: .sequentialPasteDefault
        case .manualCorrection: .defaultManualLayout
        case .disableAutomaticCorrection: .defaultDisableAutomaticLayout
        }
    }

    var persistedShortcut: ShortcutDescriptor {
        Settings.shortcut(for: self)
    }

    var fallbackTitle: String {
        switch self {
        case .history: "история доступна через значок NeClip"
        case .snippets: "папки сниппетов доступны по правому клику на NeClip"
        case .sequentialPaste: "последовательная вставка доступна в меню NeClip"
        case .manualCorrection: "ручное исправление доступно в меню"
        case .disableAutomaticCorrection: "автоисправление можно выключить в меню"
        }
    }
}

enum ShortcutUpdateResult: Equatable, Sendable {
    case applied
    case unchanged
    case rejected(String)

    var message: String? {
        if case .rejected(let message) = self { return message }
        return nil
    }
}

/// The single owner of every global shortcut. A replacement is registered
/// before the working token or persisted setting changes. Reset releases and
/// restores all five registrations as one transaction, which also supports
/// valid cross-assignments without leaving a partial shortcut set behind.
@MainActor
final class HotKeyCoordinator {
    static let shared = HotKeyCoordinator()

    private var registrations: [NeClipShortcutAction: any HotKeyRegistrationToken] = [:]
    private var callbacks: [NeClipShortcutAction: GlobalHotKey.Action] = [:]
    private var shortcuts: [NeClipShortcutAction: ShortcutDescriptor]
    private var failures: [NeClipShortcutAction: String] = [:]
    private var nextIdentifier: UInt32 = 10
    private let registrationFactory: any HotKeyRegistrationCreating
    private let reloadsPersistedShortcuts: Bool
    private let persistsSettings: Bool

    var onWarningsChanged: (([String]) -> Void)?
    var onShortcutChanged: ((NeClipShortcutAction, ShortcutDescriptor) -> Void)?

    init(
        registrationFactory: any HotKeyRegistrationCreating = CarbonHotKeyRegistrationFactory(),
        initialShortcuts: [NeClipShortcutAction: ShortcutDescriptor]? = nil,
        persistsSettings: Bool = true
    ) {
        self.registrationFactory = registrationFactory
        self.persistsSettings = persistsSettings
        reloadsPersistedShortcuts = initialShortcuts == nil
        shortcuts = initialShortcuts ?? Self.persistedShortcuts()
    }

    var allShortcuts: Set<ShortcutDescriptor> {
        Set(shortcuts.values)
    }

    func shortcut(for action: NeClipShortcutAction) -> ShortcutDescriptor {
        shortcuts[action] ?? action.defaultShortcut
    }

    func start(
        historyAction: @escaping GlobalHotKey.Action,
        snippetsAction: @escaping GlobalHotKey.Action,
        sequentialPasteAction: @escaping GlobalHotKey.Action,
        manualCorrectionAction: @escaping GlobalHotKey.Action,
        disableAutomaticCorrectionAction: @escaping GlobalHotKey.Action
    ) {
        callbacks = [
            .history: historyAction,
            .snippets: snippetsAction,
            .sequentialPaste: sequentialPasteAction,
            .manualCorrection: manualCorrectionAction,
            .disableAutomaticCorrection: disableAutomaticCorrectionAction
        ]
        if reloadsPersistedShortcuts { shortcuts = Self.persistedShortcuts() }
        registrations.removeAll()
        failures.removeAll()
        for action in NeClipShortcutAction.allCases { registerCurrent(action) }
        publishWarnings()
    }

    @discardableResult
    func update(_ action: NeClipShortcutAction, to candidate: ShortcutDescriptor) -> ShortcutUpdateResult {
        let conflicts = Set(shortcuts.compactMap { otherAction, shortcut in
            otherAction == action ? nil : shortcut
        })
        if let validation = ShortcutPolicy.validationError(for: candidate, conflictingWith: conflicts) {
            return .rejected(validation)
        }

        let current = shortcut(for: action)
        if candidate == current, registrations[action] != nil { return .unchanged }
        guard let callback = callbacks[action] else {
            return .rejected("NeClip ещё не готов менять сочетания")
        }
        let replacement: any HotKeyRegistrationToken
        do {
            replacement = try makeRegistration(for: candidate, action: callback)
        } catch {
            return .rejected(failureMessage(for: candidate, error: error))
        }

        registrations[action] = replacement
        shortcuts[action] = candidate
        failures[action] = nil
        if persistsSettings { Settings.storeShortcut(candidate, for: action) }
        onShortcutChanged?(action, candidate)
        publishWarnings()
        return .applied
    }

    func resetToDefaults() -> ShortcutUpdateResult {
        guard NeClipShortcutAction.allCases.allSatisfy({ callbacks[$0] != nil }) else {
            return .rejected("NeClip ещё не готов менять сочетания")
        }
        let alreadyDefault = NeClipShortcutAction.allCases.allSatisfy {
            shortcut(for: $0) == $0.defaultShortcut && registrations[$0] != nil
        }
        if alreadyDefault { return .unchanged }

        let previous = shortcuts
        registrations.removeAll()
        do {
            var replacements: [NeClipShortcutAction: any HotKeyRegistrationToken] = [:]
            for action in NeClipShortcutAction.allCases {
                replacements[action] = try makeRegistration(
                    for: action.defaultShortcut,
                    action: callbacks[action]!
                )
            }
            registrations = replacements
            shortcuts = Dictionary(uniqueKeysWithValues: NeClipShortcutAction.allCases.map {
                ($0, $0.defaultShortcut)
            })
            failures.removeAll()
            if persistsSettings {
                for action in NeClipShortcutAction.allCases {
                    Settings.storeShortcut(action.defaultShortcut, for: action)
                }
            }
            for action in NeClipShortcutAction.allCases {
                onShortcutChanged?(action, action.defaultShortcut)
            }
            publishWarnings()
            return .applied
        } catch {
            let resetMessage = failureMessage(for: nil, error: error)
            shortcuts = previous
            registrations.removeAll()
            failures.removeAll()
            for action in NeClipShortcutAction.allCases { registerCurrent(action) }
            publishWarnings()
            return .rejected("Не удалось восстановить стандартные сочетания: \(resetMessage)")
        }
    }

    private static func persistedShortcuts() -> [NeClipShortcutAction: ShortcutDescriptor] {
        Dictionary(uniqueKeysWithValues: NeClipShortcutAction.allCases.map {
            ($0, $0.persistedShortcut)
        })
    }

    private func registerCurrent(_ action: NeClipShortcutAction) {
        guard let callback = callbacks[action] else { return }
        do {
            registrations[action] = try makeRegistration(for: shortcut(for: action), action: callback)
            failures[action] = nil
        } catch {
            registrations[action] = nil
            failures[action] = failureMessage(for: shortcut(for: action), error: error)
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
        case .registrationFailed, .missingRegistrationReference, nil:
            return "Не удалось зарегистрировать \(chord.isEmpty ? "горячие клавиши" : chord)"
        }
    }

    private func publishWarnings() {
        onWarningsChanged?(NeClipShortcutAction.allCases.compactMap { action in
            failures[action].map { "\($0) — \(action.fallbackTitle)" }
        })
    }
}
