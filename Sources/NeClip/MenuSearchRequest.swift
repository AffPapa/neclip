import Foundation

/// Snippet keywords and template bodies are literal text, not history filters.
struct MenuSearchRequest: Equatable, Sendable {
    let history: ClipboardSearchQuery?
    let snippetTerms: String?

    init(_ raw: String, snippetsOnly: Bool) {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if snippetsOnly {
            history = nil
            snippetTerms = query
        } else {
            let parsed = ClipboardSearchQuery.parse(query)
            history = parsed
            snippetTerms = parsed.usesStructuredFilters ? nil : parsed.terms
        }
    }

    /// Choosing another value in the filter menu replaces the same dimension.
    /// Unknown colon-containing text remains literal and is never discarded.
    static func replacingFilter(in query: String, with token: String) -> String {
        func dimension(_ token: String) -> Int? {
            let parsed = ClipboardSearchQuery.parse(token)
            if parsed.kind != nil { return 0 }
            if parsed.appFragment != nil { return 1 }
            if parsed.since != nil { return 2 }
            if parsed.pinFilter != nil { return 3 }
            return nil
        }
        guard let selectedDimension = dimension(token) else { return query }
        let kept = query.split(whereSeparator: \.isWhitespace).map(String.init)
            .filter { dimension($0) != selectedDimension }
        return (kept + [token]).joined(separator: " ")
    }
}
