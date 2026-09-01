import AppKit
import ApplicationServices
import Carbon

@MainActor
final class LayoutAccessibility {
    enum Scope {
        case manual
        case automatic
    }

    struct FocusedContext {
        let pid: pid_t
        let bundleID: String
        let element: AXUIElement
        let role: String
        let selectedRange: CFRange
    }

    enum ContextFailure: Error, Equatable {
        case noPermission
        case secure
        case excluded
        case unsupported
    }

    func focusedContext(
        scope: Scope,
        userExcluded: Set<String> = []
    ) -> Result<FocusedContext, ContextFailure> {
        guard AXIsProcessTrusted() else { return .failure(.noPermission) }
        guard !IsSecureEventInputEnabled() else { return .failure(.secure) }
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier,
              !app.isTerminated,
              let bundleID = app.bundleIdentifier else { return .failure(.unsupported) }
        let blocked = scope == .automatic
            ? LayoutProtectedApplicationPolicy.blocksAutomatic(bundleID: bundleID, userExcluded: userExcluded)
            : LayoutProtectedApplicationPolicy.blocksManual(bundleID: bundleID)
        guard !blocked else {
            return .failure(.excluded)
        }

        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.2)
        guard let element: AXUIElement = attribute(application, kAXFocusedUIElementAttribute),
              let role: String = attribute(element, kAXRoleAttribute),
              isTextRole(role),
              !isSecureElement(element),
              let selectedRange = selectedRange(element) else {
            return .failure(.unsupported)
        }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &settable
        ) == .success, settable.boolValue else { return .failure(.unsupported) }

        return .success(FocusedContext(
            pid: app.processIdentifier,
            bundleID: bundleID,
            element: element,
            role: role,
            selectedRange: selectedRange
        ))
    }

    func selectedTextOrPreviousToken(in context: FocusedContext) -> (range: CFRange, text: String)? {
        if context.selectedRange.length > 0 {
            guard let text = string(in: context.selectedRange, element: context.element), !text.isEmpty else {
                return nil
            }
            return (context.selectedRange, text)
        }

        let cursor = context.selectedRange.location
        guard cursor > 0 else { return nil }
        let windowStart = max(0, cursor - 256)
        let prefixRange = CFRange(location: windowStart, length: cursor - windowStart)
        guard let prefix = string(in: prefixRange, element: context.element), !prefix.isEmpty else {
            return nil
        }
        let nsPrefix = prefix as NSString
        let separator = nsPrefix.rangeOfCharacter(
            from: .whitespacesAndNewlines,
            options: .backwards,
            range: NSRange(location: 0, length: nsPrefix.length)
        )
        let localStart = separator.location == NSNotFound ? 0 : NSMaxRange(separator)
        let length = nsPrefix.length - localStart
        guard length > 0 else { return nil }
        let range = CFRange(location: windowStart + localStart, length: length)
        guard let token = string(in: range, element: context.element), !token.isEmpty else { return nil }
        return (range, token)
    }

    func select(_ range: CFRange, in context: FocusedContext, scope: Scope = .manual) -> Bool {
        guard refreshedContext(matching: context, scope: scope) != nil else { return false }
        var mutableRange = range
        guard let value = AXValueCreate(.cfRange, &mutableRange) else { return false }
        return AXUIElementSetAttributeValue(
            context.element,
            kAXSelectedTextRangeAttribute as CFString,
            value
        ) == .success
    }

    func currentSelection(in context: FocusedContext) -> CFRange? {
        refreshedContext(matching: context, scope: .manual)?.selectedRange
    }

    func sameRange(_ lhs: CFRange, _ rhs: CFRange) -> Bool {
        lhs.location == rhs.location && lhs.length == rhs.length
    }

    func string(in range: CFRange, element: AXUIElement) -> String? {
        var mutableRange = range
        if let rangeValue = AXValueCreate(.cfRange, &mutableRange) {
            var result: CFTypeRef?
            if AXUIElementCopyParameterizedAttributeValue(
                element,
                kAXStringForRangeParameterizedAttribute as CFString,
                rangeValue,
                &result
            ) == .success, let string = result as? String {
                return string
            }
        }

        return nil
    }

    func refreshedContext(matching original: FocusedContext, scope: Scope) -> FocusedContext? {
        let exclusions = scope == .automatic ? Set(Settings.layoutExcludedApps) : []
        guard case .success(let current) = focusedContext(scope: scope, userExcluded: exclusions),
              current.pid == original.pid,
              current.bundleID == original.bundleID,
              CFEqual(current.element, original.element) else { return nil }
        return current
    }

    /// Space-only automatic correction uses one guarded AX value mutation and
    /// verifies the entire value. Its caller serializes this operation with
    /// keyboard delivery. Rich editors and longer values fail closed.
    func replaceTailAtomically(
        expected: String,
        replacement: String,
        in original: FocusedContext
    ) -> Bool {
        guard let current = refreshedContext(matching: original, scope: .automatic),
              current.selectedRange.length == 0,
              ["AXTextField", "AXSearchField", "AXComboBox"].contains(current.role),
              let countNumber: NSNumber = attribute(current.element, kAXNumberOfCharactersAttribute),
              countNumber.intValue <= 512,
              let value: String = attribute(current.element, kAXValueAttribute) else { return false }
        let characterCount = countNumber.intValue

        var valueSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(
            current.element,
            kAXValueAttribute as CFString,
            &valueSettable
        ) == .success, valueSettable.boolValue else { return false }

        let nsValue = value as NSString
        let expectedLength = (expected as NSString).length
        let cursor = current.selectedRange.location
        guard nsValue.length == characterCount,
              cursor >= expectedLength,
              cursor <= nsValue.length else { return false }
        let replacementRange = NSRange(location: cursor - expectedLength, length: expectedLength)
        guard nsValue.substring(with: replacementRange) == expected else { return false }

        let next = nsValue.replacingCharacters(in: replacementRange, with: replacement)
        // A second full-value/range read is the compare half of the CAS. User
        // input is blocked at the event-tap lock while this method runs; this
        // also rejects formatters or programmatic edits observed before set.
        guard let latest = refreshedContext(matching: current, scope: .automatic),
              sameRange(latest.selectedRange, current.selectedRange),
              let latestValue: String = attribute(latest.element, kAXValueAttribute),
              latestValue == value else { return false }
        let setResult = AXUIElementSetAttributeValue(
            current.element,
            kAXValueAttribute as CFString,
            next as CFString
        )
        guard setResult == .success else { return false }

        let replacementLength = (replacement as NSString).length
        let nextCursor = CFRange(location: replacementRange.location + replacementLength, length: 0)
        var mutableNextCursor = nextCursor
        guard let valueBeforeSelection: String = attribute(latest.element, kAXValueAttribute),
              valueBeforeSelection == next,
              let rangeValue = AXValueCreate(.cfRange, &mutableNextCursor),
              AXUIElementSetAttributeValue(
                latest.element,
                kAXSelectedTextRangeAttribute as CFString,
                rangeValue
              ) == .success,
              let verified = refreshedContext(matching: latest, scope: .automatic),
              sameRange(verified.selectedRange, nextCursor),
              let verifiedValue: String = attribute(verified.element, kAXValueAttribute),
              verifiedValue == next else {
            // Roll back only while the control still contains exactly NeClip's
            // own value. Never overwrite a concurrent third-party mutation.
            if let currentValue: String = attribute(current.element, kAXValueAttribute),
               LayoutWholeValueCASPolicy.shouldRollback(currentValue: currentValue, ownReplacement: next),
               refreshedContext(matching: current, scope: .automatic) != nil {
                _ = AXUIElementSetAttributeValue(current.element, kAXValueAttribute as CFString, value as CFString)
                var originalCursor = current.selectedRange
                if let rangeValue = AXValueCreate(.cfRange, &originalCursor) {
                    _ = AXUIElementSetAttributeValue(
                        current.element,
                        kAXSelectedTextRangeAttribute as CFString,
                        rangeValue
                    )
                }
            }
            return false
        }
        return true
    }

    private func isSecureElement(_ element: AXUIElement) -> Bool {
        let role: String? = attribute(element, kAXRoleAttribute)
        let subrole: String? = attribute(element, kAXSubroleAttribute)
        return [role, subrole].compactMap { $0?.lowercased() }.contains { token in
            token.contains("secure") || token.contains("password")
        }
    }

    private func isTextRole(_ role: String) -> Bool {
        ["AXTextField", "AXTextArea", "AXComboBox", "AXSearchField", "AXWebArea"].contains(role)
    }

    private func selectedRange(_ element: AXUIElement) -> CFRange? {
        guard let value: AXValue = attribute(element, kAXSelectedTextRangeAttribute),
              AXValueGetType(value) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range), range.location >= 0, range.length >= 0 else {
            return nil
        }
        return range
    }

    private func attribute<T>(_ element: AXUIElement, _ key: String) -> T? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &raw) == .success else {
            return nil
        }
        return raw as? T
    }

}

@MainActor
final class ManualLayoutCorrectionService {
    enum Result: Equatable {
        case corrected
        case undone
        case nothingToCorrect
        case permissionRequired
        case protectedContext
        case unsupported
        case failed
    }

    private struct UndoRecord {
        let context: LayoutAccessibility.FocusedContext
        let range: CFRange
        let original: String
        let converted: String
        let originalSourceID: String
        let switchedSource: Bool
        let createdAt: Date
    }

    private let accessibility: LayoutAccessibility
    private let layouts: KeyboardLayoutService
    private var undoRecord: UndoRecord?
    private var undoExpiry: DispatchWorkItem?

    init() {
        self.accessibility = LayoutAccessibility()
        self.layouts = .shared
    }

    init(accessibility: LayoutAccessibility, layouts: KeyboardLayoutService) {
        self.accessibility = accessibility
        self.layouts = layouts
    }

    func correctOrUndo(completion: @escaping (Result) -> Void) {
        if tryUndo(completion: completion) { return }
        let contextResult = accessibility.focusedContext(scope: .manual)
        let context: LayoutAccessibility.FocusedContext
        switch contextResult {
        case .success(let value):
            context = value
        case .failure(.noPermission):
            completion(.permissionRequired); return
        case .failure(.secure), .failure(.excluded):
            completion(.protectedContext); return
        case .failure(.unsupported):
            completion(.unsupported); return
        }

        guard let target = accessibility.selectedTextOrPreviousToken(in: context),
              let conversion = layouts.convert(target.text) else {
            completion(.nothingToCorrect); return
        }
        let shouldSwitchSource = context.selectedRange.length == 0
        guard accessibility.select(target.range, in: context) else {
            completion(.unsupported); return
        }

        PasteService.replaceSelection(
            with: conversion.converted,
            targetPID: context.pid,
            validateTarget: { [weak self] in
                guard let self,
                      let current = self.accessibility.refreshedContext(matching: context, scope: .manual),
                      let selected = self.accessibility.currentSelection(in: current) else { return false }
                return self.accessibility.sameRange(selected, target.range)
            },
            verifyReplacement: { [weak self] in
                guard let self,
                      let current = self.accessibility.refreshedContext(matching: context, scope: .manual) else {
                    return false
                }
                let replacementRange = CFRange(
                    location: target.range.location,
                    length: (conversion.converted as NSString).length
                )
                return current.selectedRange.length == 0
                    && current.selectedRange.location == replacementRange.location + replacementRange.length
                    && self.accessibility.string(in: replacementRange, element: current.element) == conversion.converted
            }
        ) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                guard result == .pasted else {
                    completion(.failed); return
                }
                var switched = false
                if shouldSwitchSource {
                    switched = self.layouts.selectSource(id: conversion.targetID)
                }
                self.undoRecord = UndoRecord(
                    context: context,
                    range: CFRange(location: target.range.location, length: (conversion.converted as NSString).length),
                    original: target.text,
                    converted: conversion.converted,
                    originalSourceID: conversion.sourceID,
                    switchedSource: switched,
                    createdAt: Date()
                )
                self.scheduleUndoExpiry()
                completion(.corrected)
            }
        }
    }

    private func tryUndo(completion: @escaping (Result) -> Void) -> Bool {
        guard let record = undoRecord else { return false }
        undoRecord = nil
        undoExpiry?.cancel()
        undoExpiry = nil
        guard Date().timeIntervalSince(record.createdAt) <= 5,
              let current = accessibility.refreshedContext(matching: record.context, scope: .manual),
              current.selectedRange.length == 0,
              current.selectedRange.location == record.range.location + record.range.length,
              accessibility.string(in: record.range, element: current.element) == record.converted,
              accessibility.select(record.range, in: current) else { return false }

        PasteService.replaceSelection(
            with: record.original,
            targetPID: current.pid,
            validateTarget: { [weak self] in
                guard let self,
                      let refreshed = self.accessibility.refreshedContext(matching: current, scope: .manual),
                      let selected = self.accessibility.currentSelection(in: refreshed) else { return false }
                return self.accessibility.sameRange(selected, record.range)
            },
            verifyReplacement: { [weak self] in
                guard let self,
                      let refreshed = self.accessibility.refreshedContext(matching: current, scope: .manual) else {
                    return false
                }
                let restoredRange = CFRange(
                    location: record.range.location,
                    length: (record.original as NSString).length
                )
                return refreshed.selectedRange.length == 0
                    && refreshed.selectedRange.location == restoredRange.location + restoredRange.length
                    && self.accessibility.string(in: restoredRange, element: refreshed.element) == record.original
            }
        ) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if result == .pasted {
                    if record.switchedSource {
                        _ = self.layouts.selectSource(id: record.originalSourceID)
                    }
                    completion(.undone)
                } else {
                    completion(.failed)
                }
            }
        }
        return true
    }

    private func scheduleUndoExpiry() {
        undoExpiry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.undoRecord = nil }
        undoExpiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}
