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
            guard isDown else {
                let shouldCorrect = optionHeld && !usedWithOtherInput && !hasOtherModifier
                optionHeld = false
                usedWithOtherInput = false
                return shouldCorrect
            }
            optionHeld = true
            usedWithOtherInput = hasOtherModifier
            return false
        case let .otherModifierChanged(hasOtherModifier):
            if optionHeld, hasOtherModifier { usedWithOtherInput = true }
            return false
        case .otherInput:
            if optionHeld { usedWithOtherInput = true }
            return false
        }
    }
}

/// Observes a standalone left or right Option release. It never suppresses
/// or changes events, and therefore leaves Option-based typing untouched.
@MainActor
final class OptionKeyCorrectionMonitor {
    private var monitor: Any?
    private var gesture = OptionKeyGesturePolicy()
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
        guard monitor == nil, LayoutPermissions.canListen else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            let observed: OptionKeyObservedEvent
            switch event.type {
            case .flagsChanged:
                let hasOtherModifier = !event.modifierFlags.intersection([.command, .control, .shift]).isEmpty
                if Self.optionKeyCodes.contains(event.keyCode) {
                    observed = .optionChanged(
                        isDown: event.modifierFlags.contains(.option),
                        hasOtherModifier: hasOtherModifier
                    )
                } else {
                    observed = .otherModifierChanged(hasOtherModifier: hasOtherModifier)
                }
            case .keyDown, .leftMouseDown, .rightMouseDown:
                observed = .otherInput
            default:
                return
            }
            Task { @MainActor [weak self] in
                self?.handle(observed)
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        gesture = OptionKeyGesturePolicy()
    }

    private func handle(_ event: OptionKeyObservedEvent) {
        if gesture.handle(event.asGestureEvent) { onTrigger?() }
    }

    private static let optionKeyCodes: Set<UInt16> = [
        UInt16(kVK_Option),
        UInt16(kVK_RightOption)
    ]
}

private enum OptionKeyObservedEvent: Sendable {
    case optionChanged(isDown: Bool, hasOtherModifier: Bool)
    case otherModifierChanged(hasOtherModifier: Bool)
    case otherInput

    var asGestureEvent: OptionKeyGestureEvent {
        switch self {
        case let .optionChanged(isDown, hasOtherModifier):
            .optionChanged(isDown: isDown, hasOtherModifier: hasOtherModifier)
        case let .otherModifierChanged(hasOtherModifier):
            .otherModifierChanged(hasOtherModifier: hasOtherModifier)
        case .otherInput:
            .otherInput
        }
    }
}
