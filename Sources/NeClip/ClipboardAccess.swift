import AppKit

enum ClipboardAccessState: Equatable, Sendable {
    case unrestricted
    case needsChoice
    case allowed
    case denied

    var permitsBackgroundRead: Bool {
        self != .denied
    }

    var needsFirstRunExplanation: Bool {
        self == .needsChoice
    }
}

enum ClipboardAccessPolicy {
    static func state(supportsPrivacyControl: Bool, rawBehavior: Int) -> ClipboardAccessState {
        guard supportsPrivacyControl else { return .unrestricted }
        switch rawBehavior {
        case 0, 1: return .needsChoice
        case 2: return .allowed
        case 3: return .denied
        default: return .denied
        }
    }
}

enum ClipboardAccess {
    static var current: ClipboardAccessState {
        guard #available(macOS 15.4, *) else { return .unrestricted }
        return ClipboardAccessPolicy.state(
            supportsPrivacyControl: true,
            rawBehavior: NSPasteboard.general.accessBehavior.rawValue
        )
    }

    @MainActor
    static func openPrivacySettings() {
        // Apple does not publish a stable deep-link anchor for the Pasteboard
        // row. Open the supported top-level Privacy & Security pane and give
        // the user the exact row name in surrounding UI copy.
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension",
            "x-apple.systempreferences:com.apple.preference.security"
        ]
        guard let url = candidates.compactMap(URL.init(string:)).first else { return }
        NSWorkspace.shared.open(url)
    }
}
