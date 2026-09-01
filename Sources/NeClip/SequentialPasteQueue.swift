import Foundation

extension Notification.Name {
    static let neClipSequentialQueueDidChange = Notification.Name(
        "org.affpapa.neclip.sequentialQueueDidChange"
    )
}

struct SequentialPasteQueueSnapshot: Equatable, Sendable {
    let isCollecting: Bool
    let total: Int
    let position: Int

    var remaining: Int { max(0, total - position) }
}

/// A deliberately ephemeral queue for copying several values and pasting them
/// one by one. Only database identifiers are held in memory; no second copy of
/// clipboard content is persisted.
final class SequentialPasteQueue: @unchecked Sendable {
    static let shared = SequentialPasteQueue()

    private let lock = NSLock()
    private let capacity: Int
    private var clipIDs: [Int64] = []
    private var position = 0
    private var collecting = false
    private var inFlightID: Int64?

    init(capacity: Int = 200) {
        self.capacity = max(1, capacity)
    }

    var snapshot: SequentialPasteQueueSnapshot {
        lock.withLock {
            SequentialPasteQueueSnapshot(
                isCollecting: collecting,
                total: clipIDs.count,
                position: position
            )
        }
    }

    func startCollecting(clearExisting: Bool = true) {
        lock.withLock {
            collecting = true
            if clearExisting {
                clipIDs.removeAll(keepingCapacity: true)
                position = 0
                inFlightID = nil
            }
        }
        notifyChanged()
    }

    func stopCollecting() {
        let changed = lock.withLock {
            guard collecting else { return false }
            collecting = false
            return true
        }
        if changed { notifyChanged() }
    }

    @discardableResult
    func appendAcceptedClip(id: Int64) -> Bool {
        append(id: id, onlyWhileCollecting: true)
    }

    @discardableResult
    func appendManual(id: Int64) -> Bool {
        append(id: id, onlyWhileCollecting: false)
    }

    func beginNext() -> Int64? {
        lock.withLock {
            if let inFlightID { return inFlightID }
            guard clipIDs.indices.contains(position) else { return nil }
            let id = clipIDs[position]
            inFlightID = id
            return id
        }
    }

    func complete(id: Int64, advance: Bool) {
        let changed = lock.withLock {
            guard inFlightID == id else { return false }
            inFlightID = nil
            if advance { position = min(position + 1, clipIDs.count) }
            return true
        }
        if changed { notifyChanged() }
    }

    func reset() {
        lock.withLock {
            position = 0
            inFlightID = nil
        }
        notifyChanged()
    }

    func clear() {
        lock.withLock {
            clipIDs.removeAll(keepingCapacity: true)
            position = 0
            inFlightID = nil
        }
        notifyChanged()
    }

    private func append(id: Int64, onlyWhileCollecting: Bool) -> Bool {
        let inserted = lock.withLock {
            if onlyWhileCollecting && !collecting { return false }
            if clipIDs.count >= capacity, position > 0 {
                clipIDs.removeFirst(position)
                position = 0
            }
            guard clipIDs.count < capacity else { return false }
            clipIDs.append(id)
            return true
        }
        if inserted { notifyChanged() }
        return inserted
    }

    private func notifyChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .neClipSequentialQueueDidChange, object: self)
        }
    }
}
