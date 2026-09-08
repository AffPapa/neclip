import Foundation

/// A deliberately small, deterministic working set for the menu-bar popup.
/// It uses only data NeClip already owns: the current frontmost app, clip
/// source metadata, and snippet usage timestamps. No new permission or state
/// is needed.
enum FocusStack {
    enum Item: Hashable, Sendable {
        case clip(ClipSummary)
        case snippet(SnippetSummary)

        var clipID: Int64? {
            guard case let .clip(clip) = self else { return nil }
            return clip.id
        }
    }

    static let defaultLimit = 5

    static func items(
        clips: [ClipSummary],
        snippets: [SnippetSummary],
        currentBundleID: String?,
        limit requestedLimit: Int = defaultLimit
    ) -> [Item] {
        let limit = max(1, min(requestedLimit, 7))
        let appClips: [ClipSummary]
        if let currentBundleID {
            appClips = clips.filter {
                $0.appBundleID?.caseInsensitiveCompare(currentBundleID) == .orderedSame
            }
        } else {
            appClips = []
        }

        // A snippet enters the working set only after the user has actually
        // used it. This keeps the popup quiet for new installations.
        let usedSnippets = snippets
            .filter { $0.useCount > 0 && $0.lastUsedAt != nil }
            .sorted {
                if $0.lastUsedAt != $1.lastUsedAt {
                    return ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast)
                }
                if $0.useCount != $1.useCount { return $0.useCount > $1.useCount }
                return ($0.id ?? 0) > ($1.id ?? 0)
            }

        var result: [Item] = []
        result.reserveCapacity(limit)
        for clip in appClips.prefix(limit) {
            result.append(.clip(clip))
        }
        for snippet in usedSnippets where result.count < limit {
            result.append(.snippet(snippet))
        }

        // One item is not a useful section: leave the regular recent list
        // alone until there is enough context to justify a new visual group.
        return result.count >= 2 ? result : []
    }
}
