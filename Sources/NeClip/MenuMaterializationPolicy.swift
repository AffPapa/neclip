import Foundation

enum MenuMaterializationPolicy {
    /// The first page remains visible in the root menu; older rows are only
    /// built after the user opens the history submenu.
    static func visibleHistoryCount(clipCount: Int, requestedVisibleCount: Int) -> Int {
        min(max(0, clipCount), max(0, requestedVisibleCount))
    }

    static func overflowRange(clipCount: Int, requestedVisibleCount: Int) -> Range<Int> {
        let visibleCount = visibleHistoryCount(
            clipCount: clipCount,
            requestedVisibleCount: requestedVisibleCount
        )
        return visibleCount..<max(visibleCount, clipCount)
    }

}
