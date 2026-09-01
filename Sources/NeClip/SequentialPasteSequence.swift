import Foundation

struct SequentialPasteSnapshot: Equatable, Sendable {
    let total: Int
    let position: Int

    var remaining: Int { max(0, total - position) }
    var isActive: Bool { remaining > 0 }
}

/// Cycles through a stable, recent-history snapshot. The snapshot is created
/// lazily on the first shortcut press, expires after inactivity, and is reset
/// when the user makes a new external copy. Only database identifiers are kept
/// in memory, so clipboard content is never duplicated.
final class SequentialPasteSequence: @unchecked Sendable {
    static let shared = SequentialPasteSequence()

    private let lock = NSLock()
    private let capacity: Int
    private let timeout: TimeInterval
    private var clipIDs: [Int64] = []
    private var position = 0
    private var inFlightID: Int64?
    private var lastActivity: Date?

    init(capacity: Int = 50, timeout: TimeInterval = 30) {
        self.capacity = max(1, capacity)
        self.timeout = max(1, timeout)
    }

    func snapshot(now: Date = Date()) -> SequentialPasteSnapshot {
        lock.withLock {
            expireIfNeeded(now: now)
            return SequentialPasteSnapshot(total: clipIDs.count, position: position)
        }
    }

    /// Returns the same identifier until `complete` records the paste result.
    /// A completed or expired sequence restarts from the supplied recent list.
    func beginNext(recentIDs: [Int64], now: Date = Date()) -> Int64? {
        lock.withLock {
            expireIfNeeded(now: now)
            if let inFlightID { return inFlightID }
            if clipIDs.isEmpty || position >= clipIDs.count {
                clipIDs = Self.uniquePrefix(recentIDs, limit: capacity)
                position = 0
            }
            guard clipIDs.indices.contains(position) else { return nil }
            let id = clipIDs[position]
            inFlightID = id
            lastActivity = now
            return id
        }
    }

    func complete(id: Int64, advance: Bool, now: Date = Date()) {
        lock.withLock {
            guard inFlightID == id else { return }
            inFlightID = nil
            if advance { position = min(position + 1, clipIDs.count) }
            lastActivity = now
        }
    }

    func isCurrent(id: Int64, now: Date = Date()) -> Bool {
        lock.withLock {
            expireIfNeeded(now: now)
            return inFlightID == id
        }
    }

    /// The next invocation starts a fresh snapshot from the latest history.
    func reset() {
        lock.withLock { clearLocked() }
    }

    /// A genuine external copy changes the expected sequence ordering.
    func noteExternalCapture() {
        reset()
    }

    private func expireIfNeeded(now: Date) {
        guard let lastActivity, now.timeIntervalSince(lastActivity) >= timeout else { return }
        clearLocked()
    }

    private func clearLocked() {
        clipIDs.removeAll(keepingCapacity: true)
        position = 0
        inFlightID = nil
        lastActivity = nil
    }

    private static func uniquePrefix(_ ids: [Int64], limit: Int) -> [Int64] {
        var seen: Set<Int64> = []
        var result: [Int64] = []
        result.reserveCapacity(min(limit, ids.count))
        for id in ids where seen.insert(id).inserted {
            result.append(id)
            if result.count == limit { break }
        }
        return result
    }
}
