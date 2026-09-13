import AppKit
import Carbon.HIToolbox

/// The state machine for the Option-only gesture is kept independent from
/// AppKit so the safety rules can be tested without reading the user's input.
enum OptionKeyGestureEvent: Equatable, Sendable {
    case optionChanged(isDown: Bool, hasOtherModifier: Bool)
    case otherModifierChanged(hasOtherModifier: Bool)
    case otherInput
}

struct OptionKeyGesturePolicy: Equatable, Sendable {
    private(set) var optionHeld = false
    private var usedWithOtherInput = false

    mutating func handle(_ event: OptionKeyGestureEvent) -> Bool {
        switch event {
        case let .optionChanged(isDown, hasOtherModifier):
            guard !isDown else {
                optionHeld = true
                usedWithOtherInput = hasOtherModifier
                return false
            }
            let shouldCorrect = optionHeld && !usedWithOtherInput && !hasOtherModifier
            optionHeld = false
            usedWithOtherInput = false
            return shouldCorrect
        case let .otherModifierChanged(hasOtherModifier):
            if optionHeld, hasOtherModifier { usedWithOtherInput = true }
            return false
        case .otherInput:
            if optionHeld { usedWithOtherInput = true }
            return false
        }
    }
}

/// Observes a standalone left or right Option release without consuming it.
/// A Quartz event tap is used instead of NSEvent's high-level global monitor:
/// it receives the same low-level stream as automatic correction and can
/// recover if macOS disables the tap after a timeout.
@MainActor
final class OptionKeyCorrectionMonitor {
    private let eventTap = OptionKeyEventTap()
    var onTrigger: (() -> Void)?

    func applySetting() {
        if Settings.manualCorrectionOptionKey {
            guard LayoutPermissions.canListen else {
                stop()
                Settings.manualCorrectionOptionKey = false
                return
            }
            start()
        } else {
            stop()
        }
    }

    func start() {
        guard LayoutPermissions.canListen else { return }
        let started = eventTap.start { [weak self] in
            Task { @MainActor [weak self] in
                self?.onTrigger?()
            }
        }
        if !started, Settings.manualCorrectionOptionKey {
            Settings.manualCorrectionOptionKey = false
        }
    }

    func stop() {
        eventTap.stop()
    }
}

private final class OptionKeyEventTap: @unchecked Sendable {
    private let lock = NSLock()
    private var gesture = OptionKeyGesturePolicy()
    private var eventTap: CFMachPort?
    private var eventSource: CFRunLoopSource?
    private var eventRunLoop: CFRunLoop?
    private var worker: Thread?
    private var startResult = false
    private var cancelled = false
    private var lastTriggerAt: TimeInterval = 0
    private var onTrigger: (@Sendable () -> Void)?

    func start(onTrigger: @escaping @Sendable () -> Void) -> Bool {
        lock.lock()
        if eventTap != nil {
            lock.unlock()
            return true
        }
        cancelled = false
        startResult = false
        gesture = OptionKeyGesturePolicy()
        self.onTrigger = onTrigger
        lock.unlock()

        let semaphore = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in run(semaphore: semaphore) }
        thread.name = "NeClip Option layout monitor"
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
        gesture = OptionKeyGesturePolicy()
        let tap = eventTap
        let runLoop = eventRunLoop
        eventTap = nil
        eventSource = nil
        eventRunLoop = nil
        onTrigger = nil
        lock.unlock()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoop { CFRunLoopStop(runLoop) }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            lock.lock()
            guard !cancelled, let tap = eventTap else {
                lock.unlock()
                return
            }
            gesture = OptionKeyGesturePolicy()
            lock.unlock()
            CGEvent.tapEnable(tap: tap, enable: true)
            return
        }

        let observed: OptionKeyGestureEvent
        switch type {
        case .flagsChanged:
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let hasOtherModifier = !flags.intersection([
                .maskCommand, .maskControl, .maskShift, .maskHelp, .maskAlphaShift
            ]).isEmpty
            if Self.optionKeyCodes.contains(keyCode) {
                observed = .optionChanged(
                    isDown: flags.contains(.maskAlternate),
                    hasOtherModifier: hasOtherModifier
                )
            } else {
                observed = .otherModifierChanged(hasOtherModifier: hasOtherModifier)
            }
        case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel:
            observed = .otherInput
        default:
            return
        }

        lock.lock()
        let shouldTrigger = !cancelled && gesture.handle(observed)
        let now = ProcessInfo.processInfo.systemUptime
        let accepted = shouldTrigger && now - lastTriggerAt >= 0.12
        if accepted { lastTriggerAt = now }
        let callback = accepted ? onTrigger : nil
        lock.unlock()
        callback?()
    }

    private func run(semaphore: DispatchSemaphore) {
        autoreleasepool {
            let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.flagsChanged.rawValue)
                | (1 << CGEventType.leftMouseDown.rawValue)
                | (1 << CGEventType.rightMouseDown.rawValue)
                | (1 << CGEventType.otherMouseDown.rawValue)
                | (1 << CGEventType.scrollWheel.rawValue)
            guard let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .tailAppendEventTap,
                options: .listenOnly,
                eventsOfInterest: mask,
                callback: neClipOptionEventCallback,
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
            CGEvent.tapEnable(tap: tap, enable: true)

            lock.lock()
            startResult = !cancelled
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

    private static let optionKeyCodes: Set<UInt16> = [
        UInt16(kVK_Option),
        UInt16(kVK_RightOption)
    ]
}

private func neClipOptionEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<OptionKeyEventTap>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}
