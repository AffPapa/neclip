import AppKit

enum SnippetMenuOrder {
    /// Browsing a folder must match the editor, independent of recent use.
    static func lessThan(_ lhs: SnippetSummary, _ rhs: SnippetSummary) -> Bool {
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return (lhs.id ?? 0) < (rhs.id ?? 0)
    }
}

enum MenuTitleFormatter {
    static let validLengthRange = 16...96
    static let defaultLimit = 64

    static func normalizedLimit(_ value: Int) -> Int {
        min(max(value, validLengthRange.lowerBound), validLengthRange.upperBound)
    }

    /// Produces a single-line menu label without changing the stored value.
    /// The limit counts Swift `Character` values, so composed Unicode glyphs
    /// are never split. The scan stops once one more visible character proves
    /// that truncation is required.
    static func format(_ value: String, limit requestedLimit: Int) -> String {
        let limit = normalizedLimit(requestedLimit)
        var result = ""
        result.reserveCapacity(limit + 1)

        var characterCount = 0
        var hasPendingWhitespace = false
        var isTruncated = false

        for character in value {
            if character.isWhitespace {
                if characterCount > 0 {
                    hasPendingWhitespace = true
                }
                continue
            }

            if hasPendingWhitespace {
                guard characterCount < limit else {
                    isTruncated = true
                    break
                }
                result.append(" ")
                characterCount += 1
                hasPendingWhitespace = false
            }

            guard characterCount < limit else {
                isTruncated = true
                break
            }
            result.append(character)
            characterCount += 1
        }

        if isTruncated {
            result.append("…")
        }
        return result
    }
}

@MainActor
enum MenuAppearance {
    /// Pins an entire menu tree to the application's effective appearance so
    /// status-item and pointer popups render identically.
    static func applyEffectiveAppearance(to menu: NSMenu) {
        apply(NSApplication.shared.effectiveAppearance, to: menu)
    }

    static func apply(_ appearance: NSAppearance, to menu: NSMenu) {
        menu.appearance = appearance
        for item in menu.items {
            item.view?.appearance = appearance
            if let submenu = item.submenu {
                apply(appearance, to: submenu)
            }
        }
    }
}
