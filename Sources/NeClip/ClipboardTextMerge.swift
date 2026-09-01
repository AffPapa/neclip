import Foundation

enum ClipboardTextMerge {
    static func join(_ existing: String, _ next: String) -> String {
        guard !existing.isEmpty else { return next }
        guard !next.isEmpty else { return existing }
        if existing.last?.isNewline == true || next.first?.isNewline == true {
            return existing + next
        }
        return existing + "\n" + next
    }

    static func title(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(200))
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

enum AppendTextResult: Equatable, Sendable {
    case appended(Int64)
    case noEligibleItem
    case combinedValueTooLarge
}
