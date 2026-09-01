import Foundation

enum SensitiveApplicationPolicy {
    static let bundleIDs: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.apple.Passwords",
        "com.apple.keychainaccess",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "org.keepassxc.keepassxc"
    ]

    private static let normalizedBundleIDs = Set(bundleIDs.map { $0.lowercased() })
    private static let displayNames = [
        "com.1password.1password": "1Password",
        "com.agilebits.onepassword7": "1Password 7",
        "com.apple.passwords": "Apple Passwords",
        "com.apple.keychainaccess": "Keychain Access",
        "com.bitwarden.desktop": "Bitwarden",
        "com.dashlane.dashlanephonefinal": "Dashlane",
        "org.keepassxc.keepassxc": "KeePassXC"
    ]

    static func protects(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return normalizedBundleIDs.contains(
            bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    static func displayName(for bundleID: String) -> String? {
        displayNames[bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }
}

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
        matches(text, normalizedRules: normalizedRules(rules))
    }

    static func matches(_ text: String, normalizedRules rules: [String]) -> Bool {
        let normalizedText = text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        return rules.contains { rule in
            normalizedText.contains(rule.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            ))
        }
    }
}
