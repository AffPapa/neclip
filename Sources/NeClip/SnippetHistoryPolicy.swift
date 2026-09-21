import Foundation

struct SnippetClipboardContext: Sendable {
    let generation: Int
    let isProtected: Bool
}

enum SnippetHistoryPolicy {
    static func rejectionReason(
        ignored: Bool, paused: Bool, clipboardAllowed: Bool,
        sourceBundleID: String?, excludedApps: Set<String>, excludedTransition: Bool
    ) -> ClipboardCaptureSkipReason? {
        if ignored { return .ignoredOnce }
        if paused { return .paused }
        if !clipboardAllowed { return .pasteboardAccessDenied }
        if ClipboardCapturePolicy.shouldRejectSource(
            bundleID: sourceBundleID, excludedTransitionActive: excludedTransition,
            excludedApps: excludedApps
        ) { return .excludedOrUnknownSource }
        return nil
    }
}
