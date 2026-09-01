import Foundation

enum ClipPinFilter: Equatable, Sendable {
    case pinned
    case history
}

enum SmartClipCategory: String, CaseIterable, Equatable, Sendable {
    case link
    case email
    case color
    case code
}

struct ClipboardSearchQuery: Equatable, Sendable {
    let raw: String
    let terms: String
    let kind: ClipKind?
    let smartCategory: SmartClipCategory?
    let appFragment: String?
    let since: Date?
    let pinFilter: ClipPinFilter?

    var usesStructuredFilters: Bool {
        kind != nil || smartCategory != nil || appFragment != nil || since != nil || pinFilter != nil
    }

    var needsPostFiltering: Bool { smartCategory != nil }

    static func parse(
        _ raw: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ClipboardSearchQuery {
        var terms: [String] = []
        var kind: ClipKind?
        var smartCategory: SmartClipCategory?
        var appFragment: String?
        var since: Date?
        var pinFilter: ClipPinFilter?

        for component in raw.split(whereSeparator: \.isWhitespace) {
            let token = String(component)
            let pieces = token.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard pieces.count == 2 else {
                terms.append(token)
                continue
            }

            let key = pieces[0].lowercased()
            let value = pieces[1].lowercased()
            var consumed = true
            switch key {
            case "type", "kind", "тип":
                switch value {
                case "text", "текст": kind = .text; smartCategory = nil
                case "image", "images", "изображение", "картинка": kind = .image; smartCategory = nil
                case "file", "files", "файл": kind = .file; smartCategory = nil
                case "link", "url", "ссылка": kind = .text; smartCategory = .link
                case "email", "mail", "почта": kind = .text; smartCategory = .email
                case "color", "colour", "цвет": kind = .text; smartCategory = .color
                case "code", "код": kind = .text; smartCategory = .code
                default: consumed = false
                }
            case "app", "source", "приложение":
                if value.isEmpty { consumed = false } else { appFragment = value }
            case "when", "age", "когда":
                switch value {
                case "today", "сегодня":
                    since = calendar.startOfDay(for: now)
                case "week", "7d", "неделя":
                    since = calendar.date(byAdding: .day, value: -7, to: now)
                case "month", "30d", "месяц":
                    since = calendar.date(byAdding: .day, value: -30, to: now)
                default: consumed = false
                }
            case "is", "state", "статус":
                switch value {
                case "pinned", "pin", "закреплено": pinFilter = .pinned
                case "history", "recent", "история": pinFilter = .history
                default: consumed = false
                }
            default:
                consumed = false
            }

            if !consumed { terms.append(token) }
        }

        return ClipboardSearchQuery(
            raw: raw,
            terms: terms.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            smartCategory: smartCategory,
            appFragment: appFragment,
            since: since,
            pinFilter: pinFilter
        )
    }
}

enum SmartClipClassifier {
    static func category(for summary: ClipSummary) -> SmartClipCategory? {
        guard summary.kind == .text else { return nil }
        let value = (summary.text ?? summary.title).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if isHTTPURL(value) { return .link }
        if isEmail(value) { return .email }
        if isColor(value) { return .color }
        if isLikelyCode(value) { return .code }
        return nil
    }

    static func matches(_ summary: ClipSummary, category: SmartClipCategory?) -> Bool {
        guard let category else { return true }
        return self.category(for: summary) == category
    }

    private static func isHTTPURL(_ value: String) -> Bool {
        guard !value.contains(where: \.isWhitespace),
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return false }
        return url.host != nil
    }

    private static func isEmail(_ value: String) -> Bool {
        guard !value.contains(where: \.isWhitespace),
              let at = value.firstIndex(of: "@"), at != value.startIndex else { return false }
        let domain = value[value.index(after: at)...]
        return domain.contains(".") && !domain.hasPrefix(".") && !domain.hasSuffix(".")
    }

    private static func isColor(_ value: String) -> Bool {
        let lowered = value.lowercased()
        if lowered.hasPrefix("#") {
            let digits = lowered.dropFirst()
            return [3, 4, 6, 8].contains(digits.count) && digits.allSatisfy(\.isHexDigit)
        }
        return ["rgb(", "rgba(", "hsl(", "hsla("].contains {
            lowered.hasPrefix($0) && lowered.hasSuffix(")")
        }
    }

    private static func isLikelyCode(_ value: String) -> Bool {
        let lowered = value.lowercased()
        let lowercaseMarkers = [
            "func ", "let ", "var ", "class ", "struct ", "import ", "return ",
            "const ", "function ", "#!/"
        ]
        let keywordMatch = lowercaseMarkers.contains { lowered.contains($0) }
            || ["SELECT ", "INSERT ", "UPDATE "].contains { value.contains($0) }
        let punctuationMatch = (value.contains("{") && value.contains("}"))
            || (value.contains(";") && (value.contains("=") || value.contains("(")))
        return keywordMatch || punctuationMatch
    }
}

enum ClipboardFuzzySearch {
    static func ranked(
        _ entries: [ClipSummary],
        query: String,
        limit: Int
    ) -> [ClipSummary] {
        let queryTokens = tokens(query)
        guard !queryTokens.isEmpty else { return Array(entries.prefix(limit)) }

        return entries.compactMap { entry -> (ClipSummary, Int)? in
            let candidate = [entry.title, entry.text ?? "", entry.appBundleID ?? ""].joined(separator: " ")
            let candidateTokens = tokens(candidate)
            guard !candidateTokens.isEmpty else { return nil }

            var total = 0
            for queryToken in queryTokens {
                if candidateTokens.contains(where: { $0.contains(queryToken) }) { continue }
                let allowed = max(1, min(3, queryToken.count / 3))
                guard let distance = candidateTokens.lazy
                    .map({ boundedDistance(queryToken, $0, maximum: allowed) })
                    .filter({ $0 <= allowed })
                    .min() else { return nil }
                total += distance
            }
            return (entry, total)
        }
        .sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            return lhs.0.createdAt > rhs.0.createdAt
        }
        .prefix(max(0, limit))
        .map(\.0)
    }

    private static func tokens(_ value: String) -> [String] {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private static func boundedDistance(_ lhs: String, _ rhs: String, maximum: Int) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        guard abs(a.count - b.count) <= maximum else { return maximum + 1 }
        if a == b { return 0 }
        if a.isEmpty { return min(b.count, maximum + 1) }
        if b.isEmpty { return min(a.count, maximum + 1) }

        var previous = Array(0...b.count)
        for (row, left) in a.enumerated() {
            var current = Array(repeating: 0, count: b.count + 1)
            current[0] = row + 1
            var rowMinimum = current[0]
            for (column, right) in b.enumerated() {
                let substitution = previous[column] + (left == right ? 0 : 1)
                current[column + 1] = min(previous[column + 1] + 1, current[column] + 1, substitution)
                rowMinimum = min(rowMinimum, current[column + 1])
            }
            if rowMinimum > maximum { return maximum + 1 }
            previous = current
        }
        return previous[b.count]
    }
}
