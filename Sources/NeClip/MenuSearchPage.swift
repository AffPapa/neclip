/// Fetch one extra result so the menu can distinguish a complete page from
/// a truncated one, without loading an unbounded history or counting all rows.
struct MenuSearchPage<Element> {
    static var limit: Int { 20 }
    let entries: [Element]
    let hasMore: Bool

    init(_ candidates: [Element]) {
        hasMore = candidates.count > Self.limit
        entries = Array(candidates.prefix(Self.limit))
    }
}
