/// Main-thread snapshot invalidation. Dirty domains survive failed or obsolete
/// reads, so coalescing notifications cannot lose a change or restore erased data.
struct MenuRefreshState {
    struct Domains: OptionSet, Sendable {
        let rawValue: Int
        static let clips = Self(rawValue: 1)
        static let snippets = Self(rawValue: 2)
        static let all: Self = [.clips, .snippets]
    }

    private(set) var domains: Domains = .all
    private(set) var generation = 0

    mutating func invalidate(_ domain: StorageChangeDomain?) {
        domains.formUnion(domain == .clips ? .clips : domain == .snippets ? .snippets : .all)
        generation += 1
    }

    mutating func begin() -> Int {
        generation += 1
        return generation
    }

    mutating func accept(_ generation: Int) -> Bool {
        guard generation == self.generation else { return false }
        domains = []
        return true
    }
}
