import Foundation

/// Isolated developer copies must never masquerade as the installed app.
enum RuntimeIdentity {
    static var previewDataDirectory: String? {
#if DEBUG
        // The bundle fallback preserves isolation when Finder relaunches a QA
        // app without the environment supplied by its original test runner.
        return nonempty(ProcessInfo.processInfo.environment["NECLIP_DATA_DIR"])
            ?? nonempty(Bundle.main.object(forInfoDictionaryKey: "NeClipPreviewDataDirectory") as? String)
#else
        return nil
#endif
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static var isIsolatedPreview: Bool { previewDataDirectory != nil }

    static var displayName: String { isIsolatedPreview ? "NeClip Preview" : "NeClip" }
}
