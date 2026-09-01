import AppKit
import Carbon.HIToolbox

enum PasteFailure: Equatable {
    case clipboardSnapshot
    case clipboardWrite
    case eventCreation
}

enum PasteResult: Equatable {
    case copiedOnly
    case copiedOnlyNoAccessibility
    case copiedOnlyTargetChanged
    case pasted
    case failed(PasteFailure)
}

enum PasteDecision: Equatable {
    case copyOnly
    case copyOnlyNoAccessibility
    case copyOnlyTargetChanged
    case paste(pid_t)
}

extension Notification.Name {
    static let neClipPasteDidFinish = Notification.Name("org.affpapa.neclip.pasteDidFinish")
}

@MainActor
enum PasteService {
    typealias Completion = @MainActor @Sendable (PasteResult) -> Void

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        // String value of kAXTrustedCheckOptionPrompt. The literal avoids a
        // Swift 6 false-positive for the imported mutable CF global.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Pure policy used by both production paste and unit tests.
    nonisolated static func decision(
        copyOnly: Bool,
        accessibilityTrusted: Bool,
        targetPID: pid_t?,
        currentPID: pid_t?
    ) -> PasteDecision {
        if copyOnly { return .copyOnly }
        guard accessibilityTrusted else { return .copyOnlyNoAccessibility }
        guard let targetPID, let currentPID, targetPID == currentPID else {
            return .copyOnlyTargetChanged
        }
        return .paste(targetPID)
    }

    nonisolated static func shouldDeleteAfterPaste(_ result: PasteResult, isPinned: Bool) -> Bool {
        result == .pasted && !isPinned
    }

    static func paste(
        _ item: ClipItem,
        plainText: Bool,
        targetPID: pid_t?,
        copyOnly: Bool = false,
        completion: Completion? = nil
    ) {
        guard write(item, plainText: plainText) else {
            finish(.failed(.clipboardWrite), completion: completion)
            return
        }
        completePaste(copyOnly: copyOnly, targetPID: targetPID, completion: completion)
    }

    static func paste(
        snippet: Snippet,
        targetPID: pid_t?,
        copyOnly: Bool = false,
        completion: Completion? = nil
    ) {
        guard writeString(snippet.content) else {
            finish(.failed(.clipboardWrite), completion: completion)
            return
        }
        completePaste(copyOnly: copyOnly, targetPID: targetPID, completion: completion)
    }

    /// Replaces an already selected range for an explicit user command, then
    /// restores the previous pasteboard only if no other process has changed
    /// it in the meantime. Auto layout correction never uses this path.
    @MainActor
    static func replaceSelection(
        with string: String,
        targetPID: pid_t,
        validateTarget: () -> Bool,
        verifyReplacement: @escaping () -> Bool,
        completion: Completion? = nil
    ) {
        guard isAccessibilityTrusted else {
            finish(.copiedOnlyNoAccessibility, completion: completion)
            return
        }

        let pasteboard = NSPasteboard.general
        let snapshotGeneration = pasteboard.changeCount
        guard let savedItems = snapshotPasteboard(pasteboard) else {
            finish(.failed(.clipboardSnapshot), completion: completion)
            return
        }
        guard pasteboard.changeCount == snapshotGeneration,
              validateTarget(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID else {
            finish(.copiedOnlyTargetChanged, completion: completion)
            return
        }
        pasteboard.clearContents()
        guard pasteboard.setString(string, forType: .string) else {
            restorePasteboard(savedItems, ifGenerationIs: pasteboard.changeCount)
            finish(.failed(.clipboardWrite), completion: completion)
            return
        }
        let replacementGeneration = pasteboard.changeCount
        ClipboardWriteGuard.shared.markOwnWrite(changeCount: replacementGeneration)

        guard validateTarget(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID else {
            restorePasteboard(savedItems, ifGenerationIs: replacementGeneration)
            finish(.copiedOnlyTargetChanged, completion: completion)
            return
        }
        guard sendCmdV(to: targetPID) else {
            restorePasteboard(savedItems, ifGenerationIs: replacementGeneration)
            finish(.failed(.eventCreation), completion: completion)
            return
        }
        confirmSelectionPaste(
            attemptsRemaining: 20,
            verifyReplacement: verifyReplacement,
            savedItems: savedItems,
            replacementGeneration: replacementGeneration,
            completion: completion
        )
    }

    @MainActor
    private static func confirmSelectionPaste(
        attemptsRemaining: Int,
        verifyReplacement: @escaping () -> Bool,
        savedItems: [NSPasteboardItem],
        replacementGeneration: Int,
        completion: Completion?
    ) {
        if verifyReplacement() {
            restorePasteboard(savedItems, ifGenerationIs: replacementGeneration)
            finish(.pasted, completion: completion)
            return
        }
        guard attemptsRemaining > 1 else {
            restorePasteboard(savedItems, ifGenerationIs: replacementGeneration)
            finish(.copiedOnlyTargetChanged, completion: completion)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(25)) {
            MainActor.assumeIsolated {
                confirmSelectionPaste(
                    attemptsRemaining: attemptsRemaining - 1,
                    verifyReplacement: verifyReplacement,
                    savedItems: savedItems,
                    replacementGeneration: replacementGeneration,
                    completion: completion
                )
            }
        }
    }

    private static func completePaste(copyOnly: Bool, targetPID: pid_t?, completion: Completion?) {
        // One main-run-loop turn lets the menu/panel finish closing. The target
        // is checked after that turn, immediately before events are posted.
        DispatchQueue.main.async {
            let currentPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
            let decision = decision(
                copyOnly: copyOnly,
                accessibilityTrusted: isAccessibilityTrusted,
                targetPID: targetPID,
                currentPID: currentPID
            )

            switch decision {
            case .copyOnly:
                finish(.copiedOnly, completion: completion)
            case .copyOnlyNoAccessibility:
                finish(.copiedOnlyNoAccessibility, completion: completion)
            case .copyOnlyTargetChanged:
                finish(.copiedOnlyTargetChanged, completion: completion)
            case .paste(let pid):
                guard sendCmdV(to: pid) else {
                    finish(.failed(.eventCreation), completion: completion)
                    return
                }
                finish(.pasted, completion: completion)
            }
        }
    }

    private static func write(_ item: ClipItem, plainText: Bool) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()

        let success: Bool
        switch item.kind {
        case .text:
            success = pb.setString(item.text ?? "", forType: .string)
            if success, !plainText, let rtf = item.rtf {
                _ = pb.setData(rtf, forType: .rtf)
            }
        case .image:
            if let data = item.data {
                success = pb.setData(data, forType: .png)
            } else {
                success = false
            }
        case .file:
            let urls = (item.text ?? "")
                .split(separator: "\n")
                .map { URL(fileURLWithPath: String($0)) }
            success = !urls.isEmpty && pb.writeObjects(urls as [NSURL])
            if success, plainText {
                _ = pb.setString(item.text ?? "", forType: .string)
            }
        }

        ClipboardWriteGuard.shared.markOwnWrite(changeCount: pb.changeCount)
        return success
    }

    private static func writeString(_ string: String) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()
        let success = pb.setString(string, forType: .string)
        ClipboardWriteGuard.shared.markOwnWrite(changeCount: pb.changeCount)
        return success
    }

    /// Captures every advertised representation or fails before the pasteboard
    /// is cleared. Returning a partial snapshot would silently destroy lazy or
    /// promised data after manual layout correction.
    static func snapshotPasteboard(_ pasteboard: NSPasteboard) -> [NSPasteboardItem]? {
        let sources = pasteboard.pasteboardItems ?? []
        return snapshotPasteboardItems(sources, advertisedTypes: pasteboard.types)
    }

    /// Kept separate from the pasteboard service so representation copying can
    /// be tested in headless environments where named pasteboards reject writes.
    static func snapshotPasteboardItems(
        _ sources: [NSPasteboardItem],
        advertisedTypes: [NSPasteboard.PasteboardType]?
    ) -> [NSPasteboardItem]? {
        if sources.isEmpty {
            return advertisedTypes?.isEmpty == false ? nil : []
        }
        var snapshot: [NSPasteboardItem] = []
        snapshot.reserveCapacity(sources.count)
        for source in sources {
            guard !source.types.isEmpty else { return nil }
            let copy = NSPasteboardItem()
            for type in source.types {
                guard let data = source.data(forType: type) else { return nil }
                guard copy.setData(data, forType: type) else { return nil }
            }
            snapshot.append(copy)
        }
        return snapshot
    }

    private static func restorePasteboard(_ items: [NSPasteboardItem], ifGenerationIs expected: Int) {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == expected else { return }
        pasteboard.clearContents()
        if !items.isEmpty { _ = pasteboard.writeObjects(items) }
        ClipboardWriteGuard.shared.markOwnWrite(changeCount: pasteboard.changeCount)
    }

    private static func sendCmdV(to pid: pid_t) -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalKeyboardEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        guard let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        ), let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        ) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(pid)
        keyUp.postToPid(pid)
        return true
    }

    private static func finish(_ result: PasteResult, completion: Completion?) {
        NotificationCenter.default.post(
            name: .neClipPasteDidFinish,
            object: nil,
            userInfo: ["result": result]
        )
        completion?(result)
    }
}
