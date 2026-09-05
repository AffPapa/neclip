import Foundation
import ServiceManagement

struct LoginItemPresentation {
    let isRequested: Bool
    let needsApproval: Bool
    let detail: String?

    init(status: SMAppService.Status) {
        switch status {
        case .enabled:
            isRequested = true
            needsApproval = false
            detail = nil
        case .requiresApproval:
            isRequested = true
            needsApproval = true
            detail = "Запуск запрошен, но ещё не разрешён macOS. Включите NeClip в «Объектах входа»."
        case .notRegistered:
            isRequested = false
            needsApproval = false
            detail = nil
        case .notFound:
            isRequested = false
            needsApproval = false
            detail = "macOS не нашла установленное приложение для запуска при входе."
        @unknown default:
            isRequested = false
            needsApproval = false
            detail = "Не удалось определить состояние запуска при входе."
        }
    }
}

enum PreferencesFeedbackPolicy {
    static func shouldExpire(current: String?, expected: String, operationRunning: Bool) -> Bool {
        !operationRunning && current == expected
    }
}

/// Describes the stored rule set without rewriting the user's text editor.
/// Storage remains the owner of normalization and its existing safety limits.
struct SensitiveRulesPresentation {
    let activeCount: Int
    let ignoredUniqueCount: Int
    let overlongCount: Int

    init(text: String) {
        let rules = text.components(separatedBy: .newlines)
        activeCount = SensitiveContentPolicy.normalizedRules(rules).count
        var keys = Set<String>()
        var longRules = 0
        for rule in rules {
            let trimmed = rule.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            // Only inspect the bounded prefix: counting every grapheme in a
            // pasted oversized rule would add work to each editor update.
            if !trimmed.dropFirst(SensitiveContentPolicy.maximumRuleLength).isEmpty { longRules += 1 }
            if let normalized = SensitiveContentPolicy.normalizedRules([trimmed]).first {
                keys.insert(normalized.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
            }
        }
        ignoredUniqueCount = max(0, keys.count - SensitiveContentPolicy.maximumRuleCount)
        overlongCount = longRules
    }

    var warning: String? {
        var messages: [String] = []
        if ignoredUniqueCount > 0 {
            messages.append("Не активны: \(ignoredUniqueCount). Применяются только первые \(SensitiveContentPolicy.maximumRuleCount) уникальных правил.")
        }
        if overlongCount > 0 {
            messages.append("Длинных фраз: \(overlongCount). Для них применяются только первые \(SensitiveContentPolicy.maximumRuleLength) символов.")
        }
        return messages.isEmpty ? nil : messages.joined(separator: " ")
    }
}

enum ApplicationExclusionUpdate: Equatable {
    case added([String])
    case alreadyExcluded
    case invalidIdentifier
}

enum ApplicationExclusionPolicy {
    static func adding(_ identifier: String, to existing: [String]) -> ApplicationExclusionUpdate {
        let identifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return .invalidIdentifier }
        guard !existing.contains(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(identifier) == .orderedSame
        }) else { return .alreadyExcluded }
        // Automatic text-correction protection and the user's layout-memory
        // exclusions are separate: Terminal/IDEs may be explicitly excluded.
        return .added(existing + [identifier])
    }
}
