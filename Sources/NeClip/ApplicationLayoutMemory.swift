import AppKit
import Carbon

enum ApplicationLayoutMemoryPolicy {
    private static let ignoredBundleIDs: Set<String> = [
        "com.apple.controlcenter",
        "com.apple.dock",
        "com.apple.loginwindow",
        "com.apple.notificationcenterui",
        "com.apple.SecurityAgent",
        "com.apple.systemuiserver"
    ]

    static func isEligible(
        bundleID: String?,
        ownBundleID: String?,
        userExcluded: Set<String>
    ) -> Bool {
        guard let bundleID = bundleID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bundleID.isEmpty,
              bundleID != ownBundleID,
              !ignoredBundleIDs.contains(bundleID),
              !userExcluded.contains(bundleID) else { return false }
        return true
    }
}

enum ApplicationLayoutRestorePolicy {
    static func sourceToRestore(
        fixedSource: String?,
        rememberedSource: String?,
        remembersLastSource: Bool
    ) -> String? {
        if let fixed = normalized(fixedSource) { return fixed }
        guard remembersLastSource else { return nil }
        return normalized(rememberedSource)
    }

    static func shouldLearnCurrentSource(fixedSource: String?, remembersLastSource: Bool) -> Bool {
        normalized(fixedSource) == nil && remembersLastSource
    }

    private static func normalized(_ source: String?) -> String? {
        guard let value = source?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}

/// Remembers only the selected TIS input source for the active application.
/// It observes no keyboard events, text fields, windows or clipboard values.
@MainActor
final class ApplicationLayoutMemoryController {
    private struct ProgrammaticSelection {
        let bundleID: String
        let sourceID: String
        let expiresAt: Date
    }

    private let layouts: KeyboardLayoutService
    private var activationObserver: NSObjectProtocol?
    private var sourceObserver: NSObjectProtocol?
    private var pendingRestore: DispatchWorkItem?
    private var activeBundleID: String?
    private var programmaticSelection: ProgrammaticSelection?

    init(layouts: KeyboardLayoutService = .shared) {
        self.layouts = layouts
    }

    func applySetting() {
        Settings.rememberLayoutPerApplication || Settings.fixedApplicationCount > 0
            ? start()
            : stop()
    }

    func start() {
        guard activationObserver == nil, sourceObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let bundleID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                .bundleIdentifier
            MainActor.assumeIsolated { self?.activate(bundleID) }
        }
        sourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.inputSourceDidChange() }
        }
        activate(NSWorkspace.shared.frontmostApplication?.bundleIdentifier)
    }

    func stop() {
        pendingRestore?.cancel()
        pendingRestore = nil
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if let sourceObserver {
            DistributedNotificationCenter.default().removeObserver(sourceObserver)
            self.sourceObserver = nil
        }
        activeBundleID = nil
        programmaticSelection = nil
    }

    private func activate(_ bundleID: String?) {
        pendingRestore?.cancel()
        pendingRestore = nil
        guard ApplicationLayoutMemoryPolicy.isEligible(
            bundleID: bundleID,
            ownBundleID: Bundle.main.bundleIdentifier,
            userExcluded: Set(Settings.layoutExcludedApps)
        ), let bundleID else {
            activeBundleID = nil
            programmaticSelection = nil
            return
        }
        activeBundleID = bundleID

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.restoreOrLearnLayout(for: bundleID) }
        }
        pendingRestore = work
        // Let an application's own per-document input-source transition settle
        // before restoring the user's last app-level choice.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(80), execute: work)
    }

    private func restoreOrLearnLayout(for bundleID: String) {
        pendingRestore = nil
        guard activeBundleID == bundleID else { return }
        let fixed = Settings.fixedLayoutSource(for: bundleID)
        let sourceToRestore = ApplicationLayoutRestorePolicy.sourceToRestore(
            fixedSource: fixed,
            rememberedSource: Settings.rememberedLayoutSource(for: bundleID),
            remembersLastSource: Settings.rememberLayoutPerApplication
        )
        if let sourceToRestore {
            guard layouts.currentSelectableSourceID() != sourceToRestore else { return }
            programmaticSelection = ProgrammaticSelection(
                bundleID: bundleID,
                sourceID: sourceToRestore,
                expiresAt: Date().addingTimeInterval(0.75)
            )
            if !layouts.selectSelectableSource(id: sourceToRestore) {
                programmaticSelection = nil
                if ApplicationLayoutRestorePolicy.shouldLearnCurrentSource(
                    fixedSource: fixed,
                    remembersLastSource: Settings.rememberLayoutPerApplication
                ), let current = layouts.currentSelectableSourceID() {
                    Settings.rememberLayoutSource(current, for: bundleID)
                }
            }
        } else if ApplicationLayoutRestorePolicy.shouldLearnCurrentSource(
            fixedSource: fixed,
            remembersLastSource: Settings.rememberLayoutPerApplication
        ), let current = layouts.currentSelectableSourceID() {
            Settings.rememberLayoutSource(current, for: bundleID)
        }
    }

    private func inputSourceDidChange() {
        guard let bundleID = activeBundleID,
              ApplicationLayoutMemoryPolicy.isEligible(
                bundleID: bundleID,
                ownBundleID: Bundle.main.bundleIdentifier,
                userExcluded: Set(Settings.layoutExcludedApps)
              ), let sourceID = layouts.currentSelectableSourceID() else { return }

        if let selection = programmaticSelection {
            programmaticSelection = nil
            if selection.expiresAt >= Date(),
               selection.bundleID == bundleID,
               selection.sourceID == sourceID {
                return
            }
        }
        guard ApplicationLayoutRestorePolicy.shouldLearnCurrentSource(
            fixedSource: Settings.fixedLayoutSource(for: bundleID),
            remembersLastSource: Settings.rememberLayoutPerApplication
        ) else { return }
        Settings.rememberLayoutSource(sourceID, for: bundleID)
    }
}
