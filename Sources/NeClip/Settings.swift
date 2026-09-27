import Foundation

enum CapturePauseState: Equatable {
    case active
    case until(Date)
    case indefinite
}

/// Keep launch arguments separate from mutable preferences. A deliberate QA or
/// command-line pause must not silently disappear when persistent state clears.
enum CapturePausePreferences {
    static let indefiniteKey = "capturePausedIndefinitely"
    static let untilKey = "capturePausedUntil"

    static func isLaunchLocked(in defaults: UserDefaults) -> Bool {
        let value = defaults.volatileDomain(forName: UserDefaults.argumentDomain)[indefiniteKey]
        if let number = value as? NSNumber { return number.boolValue }
        return (value as? NSString)?.boolValue ?? false
    }

    static func resume(in defaults: UserDefaults) {
        defaults.removeObject(forKey: indefiniteKey)
        defaults.removeObject(forKey: untilKey)
    }
}

extension Notification.Name {
    static let neClipCaptureControlsDidChange = Notification.Name("org.affpapa.neclip.captureControlsDidChange")
    static let neClipHotKeysDidChange = Notification.Name("org.affpapa.neclip.hotKeysDidChange")
}

enum Settings {
    /// Remove only preferences owned by features retired in 3.0. Clipboard,
    /// snippet, privacy, onboarding and remaining shortcut settings survive.
    static func removeRetiredPreferences(from defaults: UserDefaults = .standard) {
        for key in [
            "automaticLayoutCorrection", "manualCorrectionOptionKey", "layoutExcludedApps",
            "rememberLayoutPerApplication", "applicationLayoutMemory.v1",
            "applicationLayoutMemoryOrder.v1", "fixedApplicationLayouts.v1",
            "fixedApplicationLayoutOrder.v1", "screenshotFormat", "screenshotFolderBookmark.v1",
            "screenshotShortcut.v1", "fullScreenScreenshotShortcut.v1",
            "manualLayoutShortcut.v1", "disableAutomaticLayoutShortcut.v1"
        ] {
            defaults.removeObject(forKey: key)
        }
    }

    // UserDefaults documents thread-safe access. Swift 6 does not yet model it
    // as Sendable, so keep the single shared instance explicitly unchecked.
    nonisolated(unsafe) private static let d = UserDefaults.standard
    private static let captureControlLock = NSLock()

    private enum Key {
        static let historyLimit = "historyLimit"
        static let recentHistoryMenuLimit = "recentHistoryMenuLimit"
        static let excludedApps = "excludedApps"
        static let captureImages = "captureImages"
        static let retentionDays = "retentionDays"
        static let maximumTextCaptureKilobytes = "maximumTextCaptureKilobytes"
        static let clearHistoryOnQuit = "clearHistoryOnQuit"
        static let sensitiveContentRules = "sensitiveContentRules"
        static let preferPlainText = "preferPlainText"
        static let menuTitleLength = "menuTitleLength"
        static let capturePausedUntil = CapturePausePreferences.untilKey
        static let capturePausedIndefinitely = CapturePausePreferences.indefiniteKey
        static let ignoreNextCopy = "ignoreNextCopy"
        static let appendNextCopy = "appendNextCopy"
        static func shortcut(for action: NeClipShortcutAction) -> String {
            switch action {
            case .history: "historyShortcut.v1"
            case .snippets: "snippetsShortcut.v1"
            case .sequentialPaste: "sequentialPasteShortcut.v1"
            }
        }
    }

    static var historyLimit: Int {
        get {
            let stored = d.object(forKey: Key.historyLimit) as? Int ?? 100
            return min(1_000, max(10, stored))
        }
        set { d.set(min(1_000, max(10, newValue)), forKey: Key.historyLimit) }
    }

    /// Controls how many entries are shown directly in the first history
    /// menu. This is separate from `historyLimit`, which controls retention
    /// and deletion.
    static let recentHistoryMenuLimitRange = 10...1_000

    static var recentHistoryMenuLimit: Int {
        get {
            let stored = d.object(forKey: Key.recentHistoryMenuLimit) as? Int
                ?? recentHistoryMenuLimitRange.lowerBound
            return min(
                recentHistoryMenuLimitRange.upperBound,
                max(recentHistoryMenuLimitRange.lowerBound, stored)
            )
        }
        set {
            d.set(
                min(recentHistoryMenuLimitRange.upperBound,
                    max(recentHistoryMenuLimitRange.lowerBound, newValue)),
                forKey: Key.recentHistoryMenuLimit
            )
        }
    }

    static var excludedApps: [String] {
        get {
            normalizedBundleIDs(
                SensitiveApplicationPolicy.bundleIDs.sorted()
                    + (d.stringArray(forKey: Key.excludedApps) ?? [])
            )
        }
        set {
            d.set(
                normalizedBundleIDs(SensitiveApplicationPolicy.bundleIDs.sorted() + newValue),
                forKey: Key.excludedApps
            )
            notifyCaptureControlsChanged()
        }
    }

    static var captureImages: Bool {
        get { d.object(forKey: Key.captureImages) as? Bool ?? true }
        set {
            d.set(newValue, forKey: Key.captureImages)
            notifyCaptureControlsChanged()
        }
    }

    /// Zero keeps items until count/size limits apply. Pinned items are never
    /// removed by age.
    static var retentionDays: Int {
        get { max(0, d.integer(forKey: Key.retentionDays)) }
        set { d.set(max(0, newValue), forKey: Key.retentionDays) }
    }

    static let maximumTextCaptureKilobytesRange = 64...2_048

    static var maximumTextCaptureKilobytes: Int {
        get {
            let stored = d.object(forKey: Key.maximumTextCaptureKilobytes) as? Int ?? 2_048
            return min(maximumTextCaptureKilobytesRange.upperBound, max(maximumTextCaptureKilobytesRange.lowerBound, stored))
        }
        set {
            let normalized = min(maximumTextCaptureKilobytesRange.upperBound, max(maximumTextCaptureKilobytesRange.lowerBound, newValue))
            d.set(normalized, forKey: Key.maximumTextCaptureKilobytes)
            notifyCaptureControlsChanged()
        }
    }

    static var maximumTextCaptureBytes: Int {
        maximumTextCaptureKilobytes * 1_024
    }

    static var clearHistoryOnQuit: Bool {
        get { d.bool(forKey: Key.clearHistoryOnQuit) }
        set { d.set(newValue, forKey: Key.clearHistoryOnQuit) }
    }

    static var sensitiveContentRules: [String] {
        get { SensitiveContentPolicy.normalizedRules(d.stringArray(forKey: Key.sensitiveContentRules) ?? []) }
        set {
            d.set(SensitiveContentPolicy.normalizedRules(newValue), forKey: Key.sensitiveContentRules)
            notifyCaptureControlsChanged()
        }
    }

    static var preferPlainText: Bool {
        get { d.bool(forKey: Key.preferPlainText) }
        set { d.set(newValue, forKey: Key.preferPlainText) }
    }

    static var menuTitleLength: Int {
        get {
            let stored = d.object(forKey: Key.menuTitleLength) as? Int
            let normalized = MenuTitleFormatter.normalizedLimit(stored ?? MenuTitleFormatter.defaultLimit)
            if stored != normalized { d.set(normalized, forKey: Key.menuTitleLength) }
            return normalized
        }
        set { d.set(MenuTitleFormatter.normalizedLimit(newValue), forKey: Key.menuTitleLength) }
    }

    static var historyShortcut: ShortcutDescriptor {
        shortcut(for: .history)
    }

    static var snippetsShortcut: ShortcutDescriptor {
        shortcut(for: .snippets)
    }

    static var sequentialPasteShortcut: ShortcutDescriptor {
        shortcut(for: .sequentialPaste)
    }

    /// Persisted capture pause. An expired timed pause is cleared lazily so a
    /// relaunch never reactivates stale state.
    static var capturePauseState: CapturePauseState {
        var didExpire = false
        let state: CapturePauseState = withCaptureControlLock {
            if d.bool(forKey: Key.capturePausedIndefinitely) {
                return .indefinite
            }
            if let until = d.object(forKey: Key.capturePausedUntil) as? Date {
                if until > Date() {
                    return .until(until)
                }
                d.removeObject(forKey: Key.capturePausedUntil)
                didExpire = true
            }
            return .active
        }
        if didExpire { notifyCaptureControlsChanged() }
        return state
    }

    static var isCapturePaused: Bool {
        capturePauseState != .active
    }

    static var capturePauseIsLaunchLocked: Bool {
        withCaptureControlLock { CapturePausePreferences.isLaunchLocked(in: d) }
    }

    /// Read after requesting resume; nil means the pause actually ended.
    static var captureResumeFailureMessage: String? {
        guard isCapturePaused else { return nil }
        if capturePauseIsLaunchLocked {
            return "Запись отключена параметром запуска. Перезапустите NeClip без принудительной паузы."
        }
        return "Не удалось возобновить запись: пауза остаётся включённой."
    }

    /// `nil` means pause indefinitely. A past date is equivalent to resume.
    static func pause(until: Date?) {
        withCaptureControlLock {
            if let until, until > Date() {
                d.set(false, forKey: Key.capturePausedIndefinitely)
                d.set(until, forKey: Key.capturePausedUntil)
            } else if until == nil {
                d.set(true, forKey: Key.capturePausedIndefinitely)
                d.removeObject(forKey: Key.capturePausedUntil)
            } else {
                d.removeObject(forKey: Key.capturePausedIndefinitely)
                d.removeObject(forKey: Key.capturePausedUntil)
            }
        }
        notifyCaptureControlsChanged()
    }

    static func pauseFor15Minutes(now: Date = Date()) {
        pause(until: now.addingTimeInterval(15 * 60))
    }

    static func resumeCapture() {
        withCaptureControlLock {
            CapturePausePreferences.resume(in: d)
        }
        notifyCaptureControlsChanged()
    }

    /// Persisted one-shot flag. ClipboardMonitor consumes it atomically only
    /// for the next external pasteboard change; NeClip's own writes do not use
    /// it up.
    static var ignoreNextCopy: Bool {
        get { withCaptureControlLock { d.bool(forKey: Key.ignoreNextCopy) } }
        set {
            withCaptureControlLock {
                d.set(newValue, forKey: Key.ignoreNextCopy)
                if newValue { d.set(false, forKey: Key.appendNextCopy) }
            }
            notifyCaptureControlsChanged()
        }
    }

    @discardableResult
    static func consumeIgnoreNextCopy() -> Bool {
        let consumed = withCaptureControlLock { () -> Bool in
            guard d.bool(forKey: Key.ignoreNextCopy) else { return false }
            d.set(false, forKey: Key.ignoreNextCopy)
            return true
        }
        if consumed { notifyCaptureControlsChanged() }
        return consumed
    }

    /// One-shot append applies only to the next accepted text value. Images,
    /// files and rejected sensitive/oversized text do not consume it.
    static var appendNextCopy: Bool {
        get { withCaptureControlLock { d.bool(forKey: Key.appendNextCopy) } }
        set {
            withCaptureControlLock {
                d.set(newValue, forKey: Key.appendNextCopy)
                if newValue { d.set(false, forKey: Key.ignoreNextCopy) }
            }
            notifyCaptureControlsChanged()
        }
    }

    @discardableResult
    static func consumeAppendNextCopy() -> Bool {
        let consumed = withCaptureControlLock { () -> Bool in
            guard d.bool(forKey: Key.appendNextCopy) else { return false }
            d.set(false, forKey: Key.appendNextCopy)
            return true
        }
        if consumed { notifyCaptureControlsChanged() }
        return consumed
    }

    private static func withCaptureControlLock<T>(_ body: () -> T) -> T {
        captureControlLock.lock()
        defer { captureControlLock.unlock() }
        return body()
    }

    private static func notifyCaptureControlsChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .neClipCaptureControlsDidChange, object: nil)
        }
    }

    private static func normalizedBundleIDs(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .map(normalizedBundleID)
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func normalizedBundleID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func shortcut(for action: NeClipShortcutAction) -> ShortcutDescriptor {
        guard let data = d.data(forKey: Key.shortcut(for: action)),
              let decoded = try? JSONDecoder().decode(ShortcutDescriptor.self, from: data),
              ShortcutPolicy.validationError(for: decoded) == nil else {
            return action.defaultShortcut
        }
        return decoded
    }

    static func storeShortcut(_ shortcut: ShortcutDescriptor, for action: NeClipShortcutAction) {
        guard ShortcutPolicy.validationError(for: shortcut) == nil,
              let data = try? JSONEncoder().encode(shortcut) else { return }
        d.set(data, forKey: Key.shortcut(for: action))
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .neClipHotKeysDidChange, object: nil)
        }
    }

}
