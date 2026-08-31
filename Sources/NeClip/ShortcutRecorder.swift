import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A focusable, permission-free recorder for a single physical shortcut. It
/// observes only key events delivered to NeClip's active settings window; it
/// never installs a global event monitor or asks for Input Monitoring access.
struct ShortcutRecorder: NSViewRepresentable {
    var shortcut: ShortcutDescriptor
    var accessibilityLabel: String
    var onCandidate: @MainActor (ShortcutDescriptor) -> Void
    var onCancel: @MainActor () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCandidate: onCandidate, onCancel: onCancel)
    }

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.coordinator = context.coordinator
        button.shortcut = shortcut
        button.setAccessibilityLabel(accessibilityLabel)
        button.setAccessibilityHelp("Нажмите, затем введите новое сочетание. Escape отменяет запись.")
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        context.coordinator.onCandidate = onCandidate
        context.coordinator.onCancel = onCancel
        button.coordinator = context.coordinator
        button.shortcut = shortcut
        button.setAccessibilityLabel(accessibilityLabel)
        if !button.isRecording {
            button.title = shortcut.displayString
        }
    }

    @MainActor
    final class Coordinator {
        var onCandidate: @MainActor (ShortcutDescriptor) -> Void
        var onCancel: @MainActor () -> Void

        init(
            onCandidate: @escaping @MainActor (ShortcutDescriptor) -> Void,
            onCancel: @escaping @MainActor () -> Void
        ) {
            self.onCandidate = onCandidate
            self.onCancel = onCancel
        }
    }
}

@MainActor
final class ShortcutRecorderButton: NSButton {
    fileprivate var coordinator: ShortcutRecorder.Coordinator?
    fileprivate var shortcut: ShortcutDescriptor = .manualLayoutDefault {
        didSet {
            if !isRecording { title = shortcut.displayString }
        }
    }
    fileprivate private(set) var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        let became = super.becomeFirstResponder()
        if became && isRecording {
            title = "Нажмите сочетание…"
        }
        return became
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned && isRecording {
            cancelRecording(notify: true)
        }
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        record(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return super.performKeyEquivalent(with: event) }
        record(event)
        return true
    }

    private func configure() {
        title = shortcut.displayString
        target = self
        action = #selector(beginRecording)
        bezelStyle = .rounded
        focusRingType = .exterior
        setButtonType(.momentaryPushIn)
    }

    @objc private func beginRecording() {
        isRecording = true
        title = "Нажмите сочетание…"
        window?.makeFirstResponder(self)
        setAccessibilityValue("Запись сочетания")
    }

    private func record(_ event: NSEvent) {
        guard event.type == .keyDown, !event.isARepeat else { return }
        if event.keyCode == UInt16(kVK_Escape) {
            cancelRecording(notify: true)
            return
        }

        let candidate = ShortcutDescriptor(
            keyCode: UInt32(event.keyCode),
            modifiers: ShortcutModifiers(nsEventFlags: event.modifierFlags)
        )
        isRecording = false
        title = shortcut.displayString
        setAccessibilityValue(shortcut.displayString)
        coordinator?.onCandidate(candidate)
    }

    private func cancelRecording(notify: Bool) {
        guard isRecording else { return }
        isRecording = false
        title = shortcut.displayString
        setAccessibilityValue(shortcut.displayString)
        if notify { coordinator?.onCancel() }
    }
}
