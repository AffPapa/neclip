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
    struct Attempt: Equatable, Sendable {
        let clipID: Int64
        fileprivate let token = UUID()
    }

    enum Start: Equatable {
        case empty, busy
        case ready(Attempt)
    }

    private var inFlight: Attempt?
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

    /// Claims one paste at a time; repeated presses never share ownership.
    /// A completed or expired sequence restarts from the supplied recent list.
    func beginNext(recentIDs: [Int64], now: Date = Date()) -> Start {
        lock.withLock {
            expireIfNeeded(now: now)
            guard inFlight == nil else { return .busy }
            if clipIDs.isEmpty || position >= clipIDs.count {
                clipIDs = Self.uniquePrefix(recentIDs, limit: capacity)
                position = 0
            }
            guard clipIDs.indices.contains(position) else { return .empty }
            let attempt = Attempt(clipID: clipIDs[position])
            inFlight = attempt
            lastActivity = now
            return .ready(attempt)
        }
    }

    @discardableResult
    func complete(_ attempt: Attempt, advance: Bool, now: Date = Date()) -> Bool {
        lock.withLock {
            expireIfNeeded(now: now)
            guard inFlight == attempt else { return false }
            inFlight = nil
            if advance { position = min(position + 1, clipIDs.count) }
            lastActivity = now
            return true
        }
    }

    func isCurrent(_ attempt: Attempt, now: Date = Date()) -> Bool {
        lock.withLock {
            expireIfNeeded(now: now)
            return inFlight == attempt
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
        inFlight = nil
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
