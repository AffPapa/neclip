import Foundation

enum TextTransform: String, CaseIterable, Sendable {
    case trim
    case collapseWhitespace
    case uppercase
    case lowercase
    case titleCase
    case uniqueLines
    case sortLines
    case removeBlankLines
    case trimLines
    case urlEncode
    case urlDecode
    case jsonPretty
    case jsonMinify

    var title: String {
        switch self {
        case .trim: "Убрать пробелы по краям"
        case .collapseWhitespace: "Сжать пробелы"
        case .uppercase: "ВЕРХНИЙ РЕГИСТР"
        case .lowercase: "нижний регистр"
        case .titleCase: "Каждое Слово С Заглавной"
        case .uniqueLines: "Убрать повторяющиеся строки"
        case .sortLines: "Сортировать строки"
        case .removeBlankLines: "Убрать пустые строки"
        case .trimLines: "Убрать пробелы по краям строк"
        case .urlEncode: "Кодировать компонент URL"
        case .urlDecode: "Декодировать компонент URL"
        case .jsonPretty: "Форматировать JSON"
        case .jsonMinify: "Сжать JSON"
        }
    }

    func apply(to text: String) throws -> String {
        switch self {
        case .trim:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .collapseWhitespace:
            return text
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .titleCase:
            return text.capitalized
        case .uniqueLines:
            var seen = Set<String>()
            return Self.lines(in: text)
                .filter { seen.insert($0).inserted }
                .joined(separator: "\n")
        case .sortLines:
            return Self.lines(in: text)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .joined(separator: "\n")
        case .removeBlankLines:
            return Self.lines(in: text)
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n")
        case .trimLines:
            return Self.lines(in: text)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .joined(separator: "\n")
        case .urlEncode:
            guard let value = text.addingPercentEncoding(withAllowedCharacters: Self.urlUnreservedCharacters) else {
                throw TextTransformError.invalidURLText
            }
            return value
        case .urlDecode:
            guard let value = text.removingPercentEncoding else {
                throw TextTransformError.invalidURLText
            }
            return value
        case .jsonPretty, .jsonMinify:
            let data = Data(text.utf8)
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            var options: JSONSerialization.WritingOptions = [.sortedKeys, .fragmentsAllowed]
            if self == .jsonPretty { options.insert(.prettyPrinted) }
            return String(decoding: try JSONSerialization.data(withJSONObject: object, options: options), as: UTF8.self)
        }
    }

    private static let urlUnreservedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
    )

    private static func lines(in text: String) -> [String] {
        // Swift treats CRLF as one Character, unlike splitting a CharacterSet
        // of newline scalars, which introduces spurious empty Windows lines.
        text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
    }
}

enum TextTransformError: Error, Equatable {
    case invalidURLText
}
