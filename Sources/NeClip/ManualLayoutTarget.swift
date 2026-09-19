import Foundation

/// Keep delimiters in the replacement/undo range, but outside conversion so
/// trailing punctuation is still interpreted as punctuation by the converter.
struct ManualLayoutTarget {
    let range: CFRange
    let text: String
    let conversionText: String
    let trailingWhitespace: String

    static func selection(range: CFRange, text: String) -> Self {
        Self(range: range, text: text, conversionText: text, trailingWhitespace: "")
    }

    static func previousToken(in prefix: String, windowStart: Int) -> Self? {
        let value = prefix as NSString
        let nonWhitespace = CharacterSet.whitespacesAndNewlines.inverted
        let last = value.rangeOfCharacter(from: nonWhitespace, options: .backwards)
        guard last.location != NSNotFound else { return nil }
        let wordEnd = NSMaxRange(last)
        let separator = value.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards,
                                               range: NSRange(location: 0, length: wordEnd))
        // A bounded AX read must not convert a truncated tail of a long word.
        guard separator.location != NSNotFound || windowStart == 0 else { return nil }
        let start = separator.location == NSNotFound ? 0 : NSMaxRange(separator)
        return Self(
            range: CFRange(location: windowStart + start, length: value.length - start),
            text: value.substring(from: start),
            conversionText: value.substring(with: NSRange(location: start, length: wordEnd - start)),
            trailingWhitespace: value.substring(from: wordEnd)
        )
    }

    func replacement(with converted: String) -> String { converted + trailingWhitespace }
}
