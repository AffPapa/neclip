import Foundation

enum CapturePauseState: Equatable {
    case active
    case until(Date)
    case indefinite
}

extension Notification.Name {
    static let neClipCaptureControlsDidChange = Notification.Name("org.affpapa.neclip.captureControlsDidChange")
    static let neClipLayoutSettingsDidChange = Notification.Name("org.affpapa.neclip.layoutSettingsDidChange")
    static let neClipHotKeysDidChange = Notification.Name("org.affpapa.neclip.hotKeysDidChange")
    static let neClipManualLayoutCorrectionRequested = Notification.Name("org.affpapa.neclip.manualLayoutCorrectionRequested")
    static let neClipDisableAutomaticLayoutCorrectionRequested = Notification.Name("org.affpapa.neclip.disableAutomaticLayoutCorrectionRequested")
    static let neClipApplicationLayoutMemoryDidChange = Notification.Name("org.affpapa.neclip.applicationLayoutMemoryDidChange")
}

enum Settings {
    // UserDefaults documents thread-safe access. Swift 6 does not yet model it
    // as Sendable, so keep the single shared instance explicitly unchecked.
    nonisolated(unsafe) private static let d = UserDefaults.standard
    private static let captureControlLock = NSLock()

    private enum Key {
        static let historyLimit = "historyLimit"
        static let excludedApps = "excludedApps"
        static let captureImages = "captureImages"
        static let retentionDays = "retentionDays"
        static let maximumTextCaptureKilobytes = "maximumTextCaptureKilobytes"
        static let clearHistoryOnQuit = "clearHistoryOnQuit"
        static let sensitiveContentRules = "sensitiveContentRules"
        static let preferPlainText = "preferPlainText"
        static let menuTitleLength = "menuTitleLength"
        static let capturePausedUntil = "capturePausedUntil"
        static let capturePausedIndefinitely = "capturePausedIndefinitely"
        static let ignoreNextCopy = "ignoreNextCopy"
        static let automaticLayoutCorrection = "automaticLayoutCorrection"
        static let layoutExcludedApps = "layoutExcludedApps"
        static let rememberLayoutPerApplication = "rememberLayoutPerApplication"
        static let applicationLayoutMemory = "applicationLayoutMemory.v1"
        static let applicationLayoutMemoryOrder = "applicationLayoutMemoryOrder.v1"
        static let historyShortcut = "historyShortcut.v1"
        static let snippetsShortcut = "snippetsShortcut.v1"
        static let sequentialPasteShortcut = "sequentialPasteShortcut.v1"
        static let manualLayoutShortcut = "manualLayoutShortcut.v1"
        static let disableAutomaticLayoutShortcut = "disableAutomaticLayoutShortcut.v1"
    }

    static var historyLimit: Int {
        get {
            let stored = d.object(forKey: Key.historyLimit) as? Int ?? 100
            return min(1_000, max(10, stored))
        }
        set { d.set(min(1_000, max(10, newValue)), forKey: Key.historyLimit) }
    }

    static var excludedApps: [String] {
        get { d.stringArray(forKey: Key.excludedApps) ?? defaultExcluded }
        set { d.set(newValue, forKey: Key.excludedApps) }
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
        decodedShortcut(forKey: Key.historyShortcut, fallback: .historyDefault)
    }

    static var snippetsShortcut: ShortcutDescriptor {
        decodedShortcut(forKey: Key.snippetsShortcut, fallback: .snippetsDefault)
    }

    static var sequentialPasteShortcut: ShortcutDescriptor {
        decodedShortcut(forKey: Key.sequentialPasteShortcut, fallback: .sequentialPasteDefault)
    }

    static var manualLayoutShortcut: ShortcutDescriptor {
        decodedShortcut(forKey: Key.manualLayoutShortcut, fallback: .defaultManualLayout)
    }

    static var disableAutomaticLayoutShortcut: ShortcutDescriptor {
        decodedShortcut(forKey: Key.disableAutomaticLayoutShortcut, fallback: .defaultDisableAutomaticLayout)
    }

    static func storeHistoryShortcut(_ shortcut: ShortcutDescriptor) {
        storeShortcut(shortcut, forKey: Key.historyShortcut)
    }

    static func storeSnippetsShortcut(_ shortcut: ShortcutDescriptor) {
        storeShortcut(shortcut, forKey: Key.snippetsShortcut)
    }

    static func storeSequentialPasteShortcut(_ shortcut: ShortcutDescriptor) {
        storeShortcut(shortcut, forKey: Key.sequentialPasteShortcut)
    }

    static func storeManualLayoutShortcut(_ shortcut: ShortcutDescriptor) {
        storeShortcut(shortcut, forKey: Key.manualLayoutShortcut)
    }

    static func storeDisableAutomaticLayoutShortcut(_ shortcut: ShortcutDescriptor) {
        storeShortcut(shortcut, forKey: Key.disableAutomaticLayoutShortcut)
    }

    /// Global key listening is always explicit opt-in. Missing defaults and
    /// upgrades both remain off.
    static var automaticLayoutCorrection: Bool {
        get { d.bool(forKey: Key.automaticLayoutCorrection) }
        set {
            d.set(newValue, forKey: Key.automaticLayoutCorrection)
            notifyLayoutSettingsChanged()
        }
    }

    /// Separate from clipboard capture exclusions: these apps may still copy
    /// into history while automatic layout correction stays disabled in them.
    static var layoutExcludedApps: [String] {
        get { d.stringArray(forKey: Key.layoutExcludedApps) ?? defaultLayoutExcluded }
        set {
            d.set(Array(Set(newValue)).sorted(), forKey: Key.layoutExcludedApps)
            notifyLayoutSettingsChanged()
        }
    }

    /// This observes only application activation and the selected system input
    /// source. It never enables or depends on the automatic key-event monitor.
    static var rememberLayoutPerApplication: Bool {
        get { d.bool(forKey: Key.rememberLayoutPerApplication) }
        set {
            d.set(newValue, forKey: Key.rememberLayoutPerApplication)
            notifyLayoutSettingsChanged()
        }
    }

    static let maximumRememberedApplications = 200

    static func rememberedLayoutSource(for bundleID: String) -> String? {
        applicationLayoutMemory()[normalizedBundleID(bundleID)]
    }

    static var rememberedApplicationCount: Int {
        applicationLayoutMemory().count
    }

    static func rememberLayoutSource(_ sourceID: String, for bundleID: String) {
        let bundle = normalizedBundleID(bundleID)
        let source = sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundle.isEmpty, bundle.count <= 255, !source.isEmpty, source.count <= 512 else { return }

        var mapping = applicationLayoutMemory()
        var order = (d.stringArray(forKey: Key.applicationLayoutMemoryOrder) ?? [])
            .map(normalizedBundleID)
            .filter { !$0.isEmpty && mapping[$0] != nil && $0 != bundle }
        mapping[bundle] = source
        order.append(bundle)
        while order.count > maximumRememberedApplications {
            mapping.removeValue(forKey: order.removeFirst())
        }
        d.set(mapping, forKey: Key.applicationLayoutMemory)
        d.set(order, forKey: Key.applicationLayoutMemoryOrder)
        notifyApplicationLayoutMemoryChanged()
    }

    static func clearRememberedApplicationLayouts() {
        d.removeObject(forKey: Key.applicationLayoutMemory)
        d.removeObject(forKey: Key.applicationLayoutMemoryOrder)
        notifyApplicationLayoutMemoryChanged()
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

    /// UI-friendly alias. `.distantFuture` is stored as an indefinite pause.
    static func pauseCapture(until: Date?) {
        if until == .distantFuture {
            pause(until: nil)
        } else {
            pause(until: until)
        }
    }

    static func resumeCapture() {
        withCaptureControlLock {
            d.removeObject(forKey: Key.capturePausedIndefinitely)
            d.removeObject(forKey: Key.capturePausedUntil)
        }
        notifyCaptureControlsChanged()
    }

    /// Persisted one-shot flag. ClipboardMonitor consumes it atomically only
    /// for the next external pasteboard change; NeClip's own writes do not use
    /// it up.
    static var ignoreNextCopy: Bool {
        get { withCaptureControlLock { d.bool(forKey: Key.ignoreNextCopy) } }
        set {
            withCaptureControlLock { d.set(newValue, forKey: Key.ignoreNextCopy) }
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

    private static func notifyLayoutSettingsChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .neClipLayoutSettingsDidChange, object: nil)
        }
    }

    private static func notifyApplicationLayoutMemoryChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .neClipApplicationLayoutMemoryDidChange, object: nil)
        }
    }

    private static func applicationLayoutMemory() -> [String: String] {
        let raw = d.dictionary(forKey: Key.applicationLayoutMemory) as? [String: String] ?? [:]
        let order = d.stringArray(forKey: Key.applicationLayoutMemoryOrder) ?? []
        var result: [String: String] = [:]
        for bundle in order.suffix(maximumRememberedApplications) {
            let normalized = normalizedBundleID(bundle)
            guard !normalized.isEmpty,
                  let source = raw[bundle]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !source.isEmpty else { continue }
            result[normalized] = source
        }
        if result.isEmpty {
            for bundle in raw.keys.sorted().prefix(maximumRememberedApplications) {
                let normalized = normalizedBundleID(bundle)
                guard !normalized.isEmpty,
                      let source = raw[bundle]?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !source.isEmpty else { continue }
                result[normalized] = source
            }
        }
        return result
    }

    private static func normalizedBundleID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodedShortcut(
        forKey key: String,
        fallback: ShortcutDescriptor
    ) -> ShortcutDescriptor {
        guard let data = d.data(forKey: key),
              let decoded = try? JSONDecoder().decode(ShortcutDescriptor.self, from: data),
              ShortcutPolicy.validationError(for: decoded) == nil else {
            return fallback
        }
        return decoded
    }

    private static func storeShortcut(_ shortcut: ShortcutDescriptor, forKey key: String) {
        guard ShortcutPolicy.validationError(for: shortcut) == nil,
              let data = try? JSONEncoder().encode(shortcut) else { return }
        d.set(data, forKey: key)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .neClipHotKeysDidChange, object: nil)
        }
    }

    private static let defaultExcluded = [
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.apple.Passwords",
        "com.apple.keychainaccess",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "org.keepassxc.keepassxc"
    ]

    private static let defaultLayoutExcluded: [String] = []
}
