@testable import NeClip

extension Storage {
    /// Full bodies are useful in assertions, never in a production menu scan.
    func allSnippets(pinnedOnly: Bool = false, limit: Int? = nil) throws -> [Snippet] {
        try snippetSummaries(pinnedOnly: pinnedOnly, limit: limit)
            .compactMap(\.id).compactMap { try fetchSnippet(id: $0) }
    }
}
