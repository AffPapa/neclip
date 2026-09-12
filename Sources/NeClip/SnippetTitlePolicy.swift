import Foundation

enum SnippetTitlePolicy {
    static let maximumCharacters = 60

    /// Derives a stable, human-readable title without changing the snippet body.
    /// The first non-empty line wins; internal whitespace is compacted only in
    /// the title so pasted content remains byte-for-byte equivalent.
    static func title(for content: String) -> String {
        let line = content
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
        let compact = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(compact.prefix(maximumCharacters))
    }
}
