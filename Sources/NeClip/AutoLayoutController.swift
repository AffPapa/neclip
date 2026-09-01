import AppKit
import Carbon

@MainActor
enum LayoutPermissions {
    static var canListen: Bool { CGPreflightListenEventAccess() }
    static var canControlEvents: Bool { CGPreflightPostEventAccess() }
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestForAutomaticCorrection() -> Bool {
        if !hasAccessibility { PasteService.requestAccessibility() }
        if !canControlEvents { _ = CGRequestPostEventAccess() }
        if !canListen { _ = CGRequestListenEventAccess() }
        return hasAccessibility && canControlEvents && canListen
    }
}

@MainActor
private final class LayoutDictionary {
    private let checker = NSSpellChecker.shared
    private var languages: [String]?

    func warmUp() {
        _ = availableLanguages()
        _ = isKnown("test", language: "en")
        _ = isKnown("тест", language: "ru")
    }

    func isKnown(_ word: String, language: String) -> Bool? {
        let short = String(language.prefix(2)).lowercased()
        guard let actual = availableLanguages().first(where: {
            String($0.prefix(2)).lowercased() == short
        }) else { return nil }
        let range = checker.checkSpelling(
            of: word.lowercased(),
            startingAt: 0,
            language: actual,
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        )
        return range.location == NSNotFound
    }

    private func availableLanguages() -> [String] {
        if let languages { return languages }
        let loaded = checker.availableLanguages
        languages = loaded
        return loaded
    }
}

private struct AutoLayoutBoundary: Sendable {
    let strokes: [LayoutTypedStroke]
    let sourceID: String
    let pid: pid_t
    let contextID: UInt64
    let sequence: UInt64
}

private final class AutoLayoutEventMonitor: @unchecked Sendable {
    private struct Context {
        let sourceID: String
        let pid: pid_t
        let contextID: UInt64
        let validKeyCodes: Set<UInt16>
    }

    private let lock = NSLock()
    private var context: Context?
    private var buffer = AutoTypingBuffer(capacity: 64)
    private var sequence: UInt64 = 0
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var eventRunLoop: CFRunLoop?
    private var worker: Thread?
    private var startResult = false
    private var cancelled = false
    private var manualShortcut: ShortcutDescriptor
    private let onBoundary: @Sendable (AutoLayoutBoundary) -> Void
    private let onContextInvalidated: @Sendable () -> Void

    init(
        manualShortcut: ShortcutDescriptor,
        onBoundary: @escaping @Sendable (AutoLayoutBoundary) -> Void,
        onContextInvalidated: @escaping @Sendable () -> Void
    ) {
        self.manualShortcut = manualShortcut
        self.onBoundary = onBoundary
        self.onContextInvalidated = onContextInvalidated
    }

    func updateManualShortcut(_ shortcut: ShortcutDescriptor) {
        lock.lock()
        manualShortcut = shortcut
        lock.unlock()
    }

    func start() -> Bool {
        guard CGPreflightListenEventAccess(), CGPreflightPostEventAccess() else { return false }
        lock.lock()
        cancelled = false
        startResult = false
        lock.unlock()
        let semaphore = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            self?.run(semaphore: semaphore)
        }
        thread.name = "NeClip layout input monitor"
        thread.qualityOfService = .userInteractive
        worker = thread
        thread.start()
        guard semaphore.wait(timeout: .now() + 1) == .success else {
            stop()
            return false
        }
        lock.lock()
        let result = startResult
        lock.unlock()
        return result
    }

    func stop() {
        lock.lock()
        cancelled = true
        context = nil
        buffer.reset()
        let tap = eventTap
        let runLoop = eventRunLoop
        lock.unlock()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoop { CFRunLoopStop(runLoop) }
    }

    func updateContext(sourceID: String, pid: pid_t, contextID: UInt64, validKeyCodes: Set<UInt16>) {
        lock.lock()
        context = Context(sourceID: sourceID, pid: pid, contextID: contextID, validKeyCodes: validKeyCodes)
        buffer.reset()
        lock.unlock()
    }

    func invalidateContext() {
        lock.lock()
        context = nil
        buffer.reset()
        lock.unlock()
    }

    func currentSequence() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return sequence
    }

    /// Serializes the short Accessibility read-modify-write with delivery of
    /// new keyboard events. The event tap callback takes the same lock before
    /// forwarding each event, so a later keystroke cannot be overwritten by
    /// an older AX value snapshot.
    func performIfSequenceMatches(
        _ expected: UInt64,
        invalidateContextOnSuccess: Bool = false,
        _ operation: () -> Bool
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled, eventTap != nil, sequence == expected else { return false }
        let succeeded = operation()
        if succeeded, invalidateContextOnSuccess {
            context = nil
            buffer.reset()
        }
        return succeeded
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lock.lock()
            guard !cancelled else {
                lock.unlock()
                return
            }
            context = nil
            buffer.reset()
            let tap = eventTap
            lock.unlock()
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            onContextInvalidated()
            return
        }
        if type == .flagsChanged {
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            guard keyCode == UInt16(kVK_CapsLock) else { return }
            lock.lock()
            sequence &+= 1
            context = nil
            buffer.reset()
            lock.unlock()
            onContextInvalidated()
            return
        }

        if type == .leftMouseDown || type == .rightMouseDown {
            lock.lock()
            sequence &+= 1
            context = nil
            buffer.reset()
            lock.unlock()
            onContextInvalidated()
            return
        }
        guard type == .keyDown else { return }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        // The manual/undo hotkey itself must not invalidate its correction.
        lock.lock()
        let isManualShortcut = manualShortcut.matches(keyCode: keyCode, cgEventFlags: flags)
        lock.unlock()
        if isManualShortcut { return }

        var boundary: AutoLayoutBoundary?
        var shouldRefresh = false
        lock.lock()
        sequence &+= 1
        let eventSequence = sequence

        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            context = nil
            buffer.reset()
            shouldRefresh = true
        } else if !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty {
            context = nil
            buffer.reset()
            shouldRefresh = true
        } else if keyCode == UInt16(kVK_Space) {
            if let context {
                let strokes = buffer.takeAtBoundary()
                if !strokes.isEmpty {
                    boundary = AutoLayoutBoundary(
                        strokes: strokes,
                        sourceID: context.sourceID,
                        pid: context.pid,
                        contextID: context.contextID,
                        sequence: eventSequence
                    )
                }
            } else {
                buffer.reset()
                shouldRefresh = true
            }
        } else if keyCode == UInt16(kVK_Delete) {
            buffer.backspace()
        } else if let context,
                  context.validKeyCodes.contains(keyCode) {
            let stroke = LayoutTypedStroke(
                keyCode: keyCode,
                shift: flags.contains(.maskShift),
                capsLock: flags.contains(.maskAlphaShift)
            )
            if !buffer.append(stroke) {
                self.context = nil
                shouldRefresh = true
            }
        } else {
            context = nil
            buffer.reset()
            shouldRefresh = true
        }
        lock.unlock()

        if let boundary { onBoundary(boundary) }
        if shouldRefresh { onContextInvalidated() }
    }

    private func run(semaphore: DispatchSemaphore) {
        autoreleasepool {
            let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.flagsChanged.rawValue)
                | (1 << CGEventType.leftMouseDown.rawValue)
                | (1 << CGEventType.rightMouseDown.rawValue)
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .tailAppendEventTap,
                // An active pass-through tap never suppresses or mutates an
                // event, but its callback can briefly serialize delivery with
                // the verified AX replacement below. A passive listener could
                // observe the next key only after the target app received it.
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: neClipLayoutEventCallback,
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            ) else {
                lock.lock(); startResult = false; lock.unlock()
                semaphore.signal()
                return
            }
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            let runLoop = CFRunLoopGetCurrent()
            lock.lock()
            if cancelled {
                startResult = false
                lock.unlock()
                semaphore.signal()
                return
            }
            eventTap = tap
            eventSource = source
            eventRunLoop = runLoop
            lock.unlock()
            CFRunLoopAddSource(runLoop, source, .commonModes)

            lock.lock()
            if cancelled {
                eventTap = nil
                eventSource = nil
                eventRunLoop = nil
                startResult = false
                lock.unlock()
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
                semaphore.signal()
                return
            }
            CGEvent.tapEnable(tap: tap, enable: true)
            startResult = true
            lock.unlock()
            semaphore.signal()

            while true {
                lock.lock()
                let shouldRun = !cancelled
                lock.unlock()
                guard shouldRun else { break }
                _ = CFRunLoopRunInMode(.defaultMode, 0.1, true)
            }
            CFRunLoopRemoveSource(runLoop, source, .commonModes)
            lock.lock()
            eventTap = nil
            eventSource = nil
            eventRunLoop = nil
            startResult = false
            lock.unlock()
        }
    }
}

private func neClipLayoutEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<AutoLayoutEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}

@MainActor
final class AutoLayoutController {
    enum State: Equatable {
        case off
        case permissionRequired
        case unavailable
        case running
    }

    private struct ContextRecord {
        let id: UInt64
        let focused: LayoutAccessibility.FocusedContext
        let sourceID: String
    }

    private struct UndoRecord {
        let context: ContextRecord
        let original: String
        let converted: String
        let targetSourceID: String
        let sequence: UInt64
        let createdAt: Date
    }

    private let layouts: KeyboardLayoutService
    private let accessibility: LayoutAccessibility
    private let dictionary = LayoutDictionary()
    private var monitor: AutoLayoutEventMonitor?
    private var contextRecord: ContextRecord?
    private var nextContextID: UInt64 = 0
    private var undoRecord: UndoRecord?
    private var undoExpiry: DispatchWorkItem?
    private var contextRefreshWorkItem: DispatchWorkItem?
    private var ignoredTokens = BoundedLayoutIgnoreList()
    private var secureTimer: Timer?
    private var focusCheckCounter = 0
    private var inputSourceObserver: NSObjectProtocol?
    private(set) var state: State = .off
    var onFeedback: ((String) -> Void)?

    init() {
        self.layouts = .shared
        self.accessibility = LayoutAccessibility()
    }

    init(layouts: KeyboardLayoutService, accessibility: LayoutAccessibility) {
        self.layouts = layouts
        self.accessibility = accessibility
    }

    func applySetting() {
        if Settings.automaticLayoutCorrection {
            enable()
        } else {
            disable()
        }
    }

    func enable() {
        guard LayoutPermissions.hasAccessibility,
              LayoutPermissions.canControlEvents,
              LayoutPermissions.canListen else {
            state = .permissionRequired
            Settings.automaticLayoutCorrection = false
            return
        }
        guard layouts.layoutPair() != nil else {
            state = .unavailable
            Settings.automaticLayoutCorrection = false
            return
        }
        if monitor != nil { return }

        let created = AutoLayoutEventMonitor(
            manualShortcut: Settings.manualLayoutShortcut,
            onBoundary: { [weak self] boundary in
                DispatchQueue.main.async { self?.handle(boundary) }
            },
            onContextInvalidated: { [weak self] in
                DispatchQueue.main.async { self?.scheduleContextRefresh() }
            }
        )
        guard created.start() else {
            state = .unavailable
            Settings.automaticLayoutCorrection = false
            return
        }
        monitor = created
        state = .running
        dictionary.warmUp()
        refreshContext()
        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.layouts.invalidate()
                self.contextRecord = nil
                self.monitor?.invalidateContext()
                self.refreshContext()
            }
        }
        secureTimer?.invalidate()
        secureTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if IsSecureEventInputEnabled() {
                    self.contextRecord = nil
                    self.monitor?.invalidateContext()
                    return
                }
                self.focusCheckCounter += 1
                if self.focusCheckCounter >= 5 {
                    self.focusCheckCounter = 0
                    if let record = self.contextRecord,
                       (self.accessibility.refreshedContext(matching: record.focused, scope: .automatic) == nil
                        || self.layouts.currentSourceID() != record.sourceID) {
                        self.contextRecord = nil
                        self.monitor?.invalidateContext()
                        self.refreshContext()
                    }
                }
            }
        }
    }

    func disable() {
        contextRefreshWorkItem?.cancel()
        contextRefreshWorkItem = nil
        secureTimer?.invalidate()
        secureTimer = nil
        if let inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(inputSourceObserver)
            self.inputSourceObserver = nil
        }
        undoExpiry?.cancel()
        undoExpiry = nil
        monitor?.stop()
        monitor = nil
        contextRecord = nil
        undoRecord = nil
        state = .off
    }

    func updateManualShortcut(_ shortcut: ShortcutDescriptor) {
        monitor?.updateManualShortcut(shortcut)
    }

    func refreshContext() {
        contextRefreshWorkItem?.cancel()
        contextRefreshWorkItem = nil
        guard state == .running, let monitor else { return }
        guard case .success(let focused) = accessibility.focusedContext(
            scope: .automatic,
            userExcluded: Set(Settings.layoutExcludedApps)
        ), let sourceID = layouts.currentSourceID() else {
            contextRecord = nil
            monitor.invalidateContext()
            return
        }
        let validKeyCodes = layouts.validLetterKeyCodes(sourceID: sourceID)
        guard !validKeyCodes.isEmpty else {
            contextRecord = nil
            monitor.invalidateContext()
            return
        }
        nextContextID &+= 1
        let record = ContextRecord(id: nextContextID, focused: focused, sourceID: sourceID)
        contextRecord = record
        monitor.updateContext(
            sourceID: sourceID,
            pid: focused.pid,
            contextID: record.id,
            validKeyCodes: validKeyCodes
        )
    }

    private func scheduleContextRefresh() {
        contextRefreshWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshContext()
        }
        contextRefreshWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(40), execute: workItem)
    }

    func undoLastCorrectionIfPossible(completion: @escaping (Bool) -> Void) -> Bool {
        guard let record = undoRecord, let monitor else { return false }
        undoRecord = nil
        undoExpiry?.cancel()
        undoExpiry = nil
        guard Date().timeIntervalSince(record.createdAt) <= 5 else { return false }

        let succeeded = monitor.performIfSequenceMatches(
            record.sequence,
            invalidateContextOnSuccess: true
        ) { [self] in
            guard layouts.currentSourceID() == record.targetSourceID,
                  accessibility.replaceTailAtomically(
                    expected: record.converted + " ",
                    replacement: record.original + " ",
                    in: record.context.focused
                  ) else { return false }
            guard layouts.selectSource(id: record.context.sourceID) else {
                _ = accessibility.replaceTailAtomically(
                    expected: record.original + " ",
                    replacement: record.converted + " ",
                    in: record.context.focused
                )
                return false
            }
            return true
        }
        guard succeeded else {
            refreshContext()
            return false
        }
        ignoredTokens.add(record.original)
        completion(true)
        refreshContext()
        return true
    }

    private func handle(_ boundary: AutoLayoutBoundary) {
        guard state == .running,
              let monitor,
              monitor.currentSequence() == boundary.sequence,
              let context = contextRecord,
              context.id == boundary.contextID,
              context.sourceID == boundary.sourceID,
              context.focused.pid == boundary.pid,
              contextStillMatches(context),
              layouts.currentSourceID() == boundary.sourceID,
              let translation = layouts.translate(strokes: boundary.strokes, sourceID: boundary.sourceID),
              !ignoredTokens.contains(translation.original),
              LayoutTextPolicy.isAutoCandidate(translation.original),
              LayoutTextPolicy.isAutoCandidate(translation.converted),
              let typedKnown = dictionary.isKnown(translation.original, language: translation.sourceLanguage),
              let convertedKnown = dictionary.isKnown(translation.converted, language: translation.targetLanguage),
              AutoLayoutDecisionPolicy.decide(
                typed: translation.original,
                converted: translation.converted,
                typedIsKnownWord: typedKnown,
                convertedIsKnownWord: convertedKnown
              ) == .correct,
              monitor.currentSequence() == boundary.sequence else { return }

        let corrected = monitor.performIfSequenceMatches(
            boundary.sequence,
            invalidateContextOnSuccess: true
        ) { [self] in
            guard layouts.currentSourceID() == boundary.sourceID,
                  accessibility.replaceTailAtomically(
                    expected: translation.original + " ",
                    replacement: translation.converted + " ",
                    in: context.focused
                  ) else { return false }
            guard layouts.selectSource(id: translation.targetID) else {
                _ = accessibility.replaceTailAtomically(
                    expected: translation.converted + " ",
                    replacement: translation.original + " ",
                    in: context.focused
                )
                return false
            }
            return true
        }
        guard corrected else { return }

        undoRecord = UndoRecord(
            context: context,
            original: translation.original,
            converted: translation.converted,
            targetSourceID: translation.targetID,
            sequence: boundary.sequence,
            createdAt: Date()
        )
        scheduleUndoExpiry()
        onFeedback?("Раскладка исправлена · \(Settings.manualLayoutShortcut.displayString) — отменить")
        refreshContext()
    }

    private func contextStillMatches(_ record: ContextRecord) -> Bool {
        guard let current = accessibility.refreshedContext(matching: record.focused, scope: .automatic),
              current.pid == record.focused.pid,
              current.bundleID == record.focused.bundleID else { return false }
        return true
    }

    private func scheduleUndoExpiry() {
        undoExpiry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.undoRecord = nil }
        undoExpiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}
