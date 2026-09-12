import Foundation

enum SnippetRenderer {
    private typealias Token = SnippetTokenCatalog.Token

    private static let patterns = Token.allCases.map {
        (bytes: Array(("{" + $0.rawValue + "}").utf8), token: $0, escaped: true)
    } + Token.allCases.map { (bytes: Array($0.rawValue.utf8), token: $0, escaped: false) }

    static func render(
        _ content: String,
        clipboard: String? = nil,
        date: Date = Date(),
        locale: Locale = .current,
        timeZone: TimeZone = .current,
        maxOutputBytes: Int = ClipboardCapturePolicy.maxTextBytes
    ) throws -> String {
        let limit = max(0, maxOutputBytes)
        guard content.utf8.contains(123) else {
            guard content.utf8.count <= limit else {
                throw SnippetRenderingError.outputTooLarge(maximumBytes: limit)
            }
            return content
        }
        var values: [Token: String] = [:]
        func value(for token: Token) -> String {
            if let cached = values[token] { return cached }
            let result: String
            if token == .clipboard {
                result = clipboard ?? ""
            } else {
                let formatter = DateFormatter()
                formatter.timeZone = timeZone
                if token == .isoDate || token == .isoTime {
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.calendar = Calendar(identifier: .gregorian)
                    formatter.dateFormat = token == .isoDate ? "yyyy-MM-dd" : "HH:mm:ss"
                } else {
                    formatter.locale = locale
                    formatter.dateStyle = token == .date ? .short : .none
                    formatter.timeStyle = token == .time ? .short : .none
                }
                result = formatter.string(from: date)
            }
            values[token] = result
            return result
        }

        let input = Array(content.utf8)
        var result: [UInt8] = []
        result.reserveCapacity(min(input.count, limit))
        func append<Bytes: Collection>(_ bytes: Bytes) throws where Bytes.Element == UInt8 {
            guard bytes.count <= limit - result.count else {
                throw SnippetRenderingError.outputTooLarge(maximumBytes: limit)
            }
            result.append(contentsOf: bytes)
        }
        var cursor = 0
        // Scan only the template. Inserted clipboard text is never interpreted
        // as another token; double braces escape a known token literally.
        // ASCII token bytes can be matched without repeated UTF-16 index
        // conversion; this also preserves combining marks adjacent to braces.
        while let opening = input[cursor...].firstIndex(of: 123) {
            try append(input[cursor..<opening])
            var matched = false
            for pattern in patterns {
                guard pattern.bytes.count <= input.count - opening else { continue }
                let end = opening + pattern.bytes.count
                guard input[opening..<end].elementsEqual(pattern.bytes) else { continue }
                try append((pattern.escaped ? pattern.token.rawValue : value(for: pattern.token)).utf8)
                cursor = end
                matched = true
                break
            }
            if !matched {
                try append(CollectionOfOne(UInt8(123)))
                cursor = opening + 1
            }
        }
        try append(input[cursor...])
        return String(decoding: result, as: UTF8.self)
    }
}

enum SnippetRenderingError: LocalizedError, Equatable {
    case outputTooLarge(maximumBytes: Int)

    var errorDescription: String? {
        switch self {
        case .outputTooLarge(let maximumBytes):
            "После подстановок сниппет превышает лимит \(ByteCountFormatter.string(fromByteCount: Int64(maximumBytes), countStyle: .file)). Сократите шаблон или содержимое буфера."
        }
    }
}
