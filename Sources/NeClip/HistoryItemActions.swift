import Foundation

enum HistoryItemActionResolver {
    static func webURL(_ text: String) -> URL? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.contains(where: \.isWhitespace),
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }

    static func openTarget(for item: ClipItem, fileExists: (String) -> Bool = {
        FileManager.default.fileExists(atPath: $0)
    }) -> URL? {
        switch item.kind {
        case .text:
            return item.text.flatMap(webURL)
        case .file:
            guard let firstPath = item.text?
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map(String.init)
                .first,
                fileExists(firstPath) else { return nil }
            return URL(fileURLWithPath: firstPath)
        case .image:
            return nil
        }
    }
}
