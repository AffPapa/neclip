import AppKit

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

    @MainActor
    static func configurePreviewWindow(_ window: NSWindow) {
#if DEBUG
        guard isIsolatedPreview else { return }
        let environment = ProcessInfo.processInfo.environment
        if let appearance = environment["NECLIP_UI_TEST_APPEARANCE"],
           appearance == "light" || appearance == "dark" {
            window.appearance = NSAppearance(named: appearance == "dark" ? .darkAqua : .aqua)
        }
        if environment["NECLIP_UI_TEST_MINIMUM_WINDOWS"] == "1" {
            window.setFrame(NSRect(origin: window.frame.origin, size: window.minSize), display: false)
        }
#endif
    }
}
