import Foundation

enum SensitiveContentPolicy {
    static let maximumRuleCount = 50
    static let maximumRuleLength = 200

    static func normalizedRules(_ rules: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in rules {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let bounded = String(trimmed.prefix(maximumRuleLength))
            let key = bounded.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            guard seen.insert(key).inserted else { continue }
            result.append(bounded)
            if result.count == maximumRuleCount { break }
        }
        return result
    }

    static func matches(_ text: String, rules: [String]) -> Bool {
        let normalizedText = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return normalizedRules(rules).contains { rule in
            normalizedText.contains(rule.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ))
        }
    }
}
