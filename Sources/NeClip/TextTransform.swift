import Foundation

enum TextTransform: String, CaseIterable, Sendable {
    case trim
    case collapseWhitespace
    case uppercase
    case lowercase
    case titleCase
    case uniqueLines
    case sortLines
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
        case .urlEncode: "Кодировать URL"
        case .urlDecode: "Декодировать URL"
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
            return text.components(separatedBy: .newlines)
                .filter { seen.insert($0).inserted }
                .joined(separator: "\n")
        case .sortLines:
            return text.components(separatedBy: .newlines)
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                .joined(separator: "\n")
        case .urlEncode:
            guard let value = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
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
}

enum TextTransformError: Error, Equatable {
    case invalidURLText
}
