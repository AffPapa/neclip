import Foundation

enum MenuMaterializationPolicy {
    /// Action rows are fixed per clip; folder targets must be created only for
    /// the one action submenu that the user opens.
    static func eagerItemCount(clipCount: Int) -> Int {
        max(0, clipCount)
    }

    static func openedActionItemCount(folderCount: Int, includesOpenTarget: Bool) -> Int {
        // Paste, plain text, copy, save target, optional separator, folders,
        // and an optional open-target command.
        4 + max(0, folderCount) + (folderCount > 0 ? 1 : 0) + (includesOpenTarget ? 1 : 0)
    }
}
