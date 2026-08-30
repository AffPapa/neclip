import Foundation

/// Prevents clipboard writes performed by NeClip itself from being captured
/// as new history entries. Pasteboard change counts are process-global and
/// monotonically increasing, so matching the exact final count avoids a
/// time-based suppression window that could hide a real user copy.
final class ClipboardWriteGuard: @unchecked Sendable {
    static let shared = ClipboardWriteGuard()

    private let lock = NSLock()
    private var ownChangeCounts: Set<Int> = []
    private var insertionOrder: [Int] = []
    private let capacity: Int

    init(capacity: Int = 32) {
        self.capacity = max(1, capacity)
    }

    func markOwnWrite(changeCount: Int) {
        lock.lock()
        defer { lock.unlock() }

        guard ownChangeCounts.insert(changeCount).inserted else { return }
        insertionOrder.append(changeCount)

        while insertionOrder.count > capacity {
            let expired = insertionOrder.removeFirst()
            ownChangeCounts.remove(expired)
        }
    }

    func consumeIfOwn(changeCount: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard ownChangeCounts.remove(changeCount) != nil else { return false }
        insertionOrder.removeAll { $0 == changeCount }
        return true
    }
}
