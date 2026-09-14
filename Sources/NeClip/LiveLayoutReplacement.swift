import Foundation

enum LiveLayoutReplacementResult: Equatable {
    case replaced
    case notReady
    case rejected
    case uncertain
}

/// All closures validate the same focused element. Only the token is selected
/// and replaced; surrounding rich text and the pasteboard are never rewritten.
struct LiveLayoutRangeAccess {
    var selection: () -> CFRange?
    var text: (CFRange) -> String?
    var select: (CFRange) -> Bool
    var replaceSelection: (String) -> Bool

    func replaceTail(expected: String, replacement: String) -> LiveLayoutReplacementResult {
        guard !expected.isEmpty, let caret = selection(), caret.length == 0 else { return .rejected }
        let length = (expected as NSString).length
        guard caret.location >= length else { return .notReady }
        let target = CFRange(location: caret.location - length, length: length)
        guard text(target) == expected else { return .notReady }
        // A context refresh can miss a leading key. Never correct a matching
        // suffix of a larger token, e.g. the last four letters of a valid word.
        if target.location > 0 {
            guard let preceding = text(CFRange(location: target.location - 1, length: 1)),
                  !preceding.contains(where: { $0.isLetter || $0.isNumber || $0 == "_" }) else {
                return .rejected
            }
        }
        guard same(selection(), caret), text(target) == expected else { return .rejected }
        guard select(target) else { return .rejected }
        guard same(selection(), target), text(target) == expected else {
            // Restore only our own selection on unchanged text, never a user's
            // later selection or a programmatic edit.
            restoreOwnedSelection(target, caret: caret)
            return .rejected
        }
        // A failed/ambiguous write is terminal: retrying could duplicate text.
        guard replaceSelection(replacement) else {
            restoreOwnedSelection(target, caret: caret)
            return .uncertain
        }
        let changed = CFRange(location: target.location, length: (replacement as NSString).length)
        guard let after = selection(),
              LayoutReplacementVerificationPolicy.accepts(
                selectedRange: after, replacementRange: changed, textMatches: text(changed) == replacement
              ) else { return .uncertain }
        let end = CFRange(location: changed.location + changed.length, length: 0)
        if !same(after, end) {
            guard select(end), same(selection(), end), text(changed) == replacement else { return .uncertain }
        }
        return .replaced
    }

    private func same(_ lhs: CFRange?, _ rhs: CFRange) -> Bool {
        lhs?.location == rhs.location && lhs?.length == rhs.length
    }

    private func restoreOwnedSelection(_ target: CFRange, caret: CFRange) {
        // Even if a formatter changed the text, leaving our temporary range
        // selected would make the next key delete it. Preserve any selection
        // changed independently, and restore only a still-valid caret.
        guard same(selection(), target),
              text(CFRange(location: caret.location, length: 0)) != nil else { return }
        _ = select(caret)
    }
}

struct LayoutManualSuspension {
    private(set) var depth = 0
    var isSuspended: Bool { depth > 0 }
    mutating func begin() { depth += 1 }
    mutating func end() { depth = max(0, depth - 1) }
}

/// A key reaches the event tap before an editor updates its AX text. Recheck
/// that same candidate briefly, but never after another key/focus/source epoch.
enum LiveLayoutRetryPolicy {
    static let initialDelay: TimeInterval = 0.012
    static let retryDelays: [TimeInterval] = [0.020, 0.040, 0.080]

    static func delay(after result: LiveLayoutReplacementResult, attempt: Int,
                      sequence: UInt64, currentSequence: UInt64) -> TimeInterval? {
        guard result == .notReady, sequence == currentSequence,
              retryDelays.indices.contains(attempt) else { return nil }
        return retryDelays[attempt]
    }
}
