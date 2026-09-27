import Foundation

enum SnippetClipboardReadError: Error { case clipboardChanged }

/// Read only for an active clipboard token, without mixing clipboard generations.
enum SnippetClipboardRead {
    static func readIfNeeded(template: String, expectedGeneration: Int,
                             readGeneration: () -> Int, readText: () -> String?) throws -> String? {
        guard SnippetRenderer.usesClipboard(template) else { return nil }
        guard readGeneration() == expectedGeneration else { throw SnippetClipboardReadError.clipboardChanged }
        let text = readText()
        guard readGeneration() == expectedGeneration else { throw SnippetClipboardReadError.clipboardChanged }
        return text
    }
}
