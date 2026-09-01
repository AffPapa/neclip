import AppKit
import Carbon.HIToolbox

/// The four modifiers NeClip accepts for a global shortcut. Persisting our own
/// compact bit set keeps UserDefaults independent of AppKit and Carbon raw
/// values while the conversion helpers keep those framework boundaries exact.
struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt8

    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let control = ShortcutModifiers(rawValue: 1 << 1)
    static let option = ShortcutModifiers(rawValue: 1 << 2)
    static let shift = ShortcutModifiers(rawValue: 1 << 3)

    private static let supportedMask: UInt8 = 0b0000_1111
    static let supported: ShortcutModifiers = [.command, .control, .option, .shift]

    init(rawValue: UInt8) {
        self.rawValue = rawValue & Self.supportedMask
    }

    init(nsEventFlags: NSEvent.ModifierFlags) {
        var value: ShortcutModifiers = []
        if nsEventFlags.contains(.command) { value.insert(.command) }
        if nsEventFlags.contains(.control) { value.insert(.control) }
        if nsEventFlags.contains(.option) { value.insert(.option) }
        if nsEventFlags.contains(.shift) { value.insert(.shift) }
        self = value
    }

    init(carbonModifiers: UInt32) {
        var value: ShortcutModifiers = []
        if carbonModifiers & UInt32(cmdKey) != 0 { value.insert(.command) }
        if carbonModifiers & UInt32(controlKey) != 0 { value.insert(.control) }
        if carbonModifiers & UInt32(optionKey) != 0 { value.insert(.option) }
        if carbonModifiers & UInt32(shiftKey) != 0 { value.insert(.shift) }
        self = value
    }

    init(cgEventFlags: CGEventFlags) {
        var value: ShortcutModifiers = []
        if cgEventFlags.contains(.maskCommand) { value.insert(.command) }
        if cgEventFlags.contains(.maskControl) { value.insert(.control) }
        if cgEventFlags.contains(.maskAlternate) { value.insert(.option) }
        if cgEventFlags.contains(.maskShift) { value.insert(.shift) }
        self = value
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if contains(.command) { value |= UInt32(cmdKey) }
        if contains(.control) { value |= UInt32(controlKey) }
        if contains(.option) { value |= UInt32(optionKey) }
        if contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    var nsEventFlags: NSEvent.ModifierFlags {
        var value: NSEvent.ModifierFlags = []
        if contains(.command) { value.insert(.command) }
        if contains(.control) { value.insert(.control) }
        if contains(.option) { value.insert(.option) }
        if contains(.shift) { value.insert(.shift) }
        return value
    }

    var cgEventFlags: CGEventFlags {
        var value: CGEventFlags = []
        if contains(.command) { value.insert(.maskCommand) }
        if contains(.control) { value.insert(.maskControl) }
        if contains(.option) { value.insert(.maskAlternate) }
        if contains(.shift) { value.insert(.maskShift) }
        return value
    }

    var count: Int {
        rawValue.nonzeroBitCount
    }

    var displayPrefix: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decoded = try container.decode(UInt8.self)
        guard decoded & ~Self.supportedMask == 0 else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported shortcut modifier bits"
            )
        }
        self.init(rawValue: decoded)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A layout-independent physical shortcut. NeClip intentionally accepts only
/// ANSI letter and number positions so recording, menu display and Carbon
/// registration stay predictable when the user changes keyboard layouts.
struct ShortcutDescriptor: Codable, Hashable, Sendable {
    let keyCode: UInt32
    let modifiers: ShortcutModifiers

    static let manualLayoutDefault = ShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_L),
        modifiers: [.option, .shift]
    )
    static let defaultManualLayout = manualLayoutDefault

    /// An off-only safety shortcut: it must never enable input monitoring.
    static let disableAutomaticLayoutDefault = ShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_A),
        modifiers: [.control, .option]
    )
    static let defaultDisableAutomaticLayout = disableAutomaticLayoutDefault

    static let historyDefault = ShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: [.command, .shift]
    )

    static let snippetsDefault = ShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_B),
        modifiers: [.command, .shift]
    )

    static let sequentialPasteDefault = ShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: [.control, .command]
    )

    var keyLabel: String? {
        Self.keyLabels[keyCode]
    }

    var displayString: String {
        modifiers.displayPrefix + (keyLabel ?? "?")
    }
    var displayName: String { displayString }

    /// Suitable for an AppKit menu item's key equivalent. Registration still
    /// uses `keyCode`, so this presentation value never changes shortcut
    /// identity.
    var keyEquivalent: String? {
        keyLabel?.lowercased()
    }

    var carbonModifiers: UInt32 {
        modifiers.carbonModifiers
    }

    var nsEventModifiers: NSEvent.ModifierFlags {
        modifiers.nsEventFlags
    }

    func matches(keyCode candidateKeyCode: UInt32, modifiers candidateModifiers: ShortcutModifiers) -> Bool {
        keyCode == candidateKeyCode && modifiers == candidateModifiers
    }

    func matches(keyCode candidateKeyCode: UInt16, cgEventFlags: CGEventFlags) -> Bool {
        matches(
            keyCode: UInt32(candidateKeyCode),
            modifiers: ShortcutModifiers(cgEventFlags: cgEventFlags)
        )
    }

    func matches(event: NSEvent) -> Bool {
        matches(
            keyCode: UInt32(event.keyCode),
            modifiers: ShortcutModifiers(nsEventFlags: event.modifierFlags)
        )
    }

    static func isSupportedKeyCode(_ keyCode: UInt32) -> Bool {
        keyLabels[keyCode] != nil
    }

    private static let keyLabels: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B",
        UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
        UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
        UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J",
        UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N",
        UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
        UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
        UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V",
        UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1",
        UInt32(kVK_ANSI_2): "2", UInt32(kVK_ANSI_3): "3",
        UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7",
        UInt32(kVK_ANSI_8): "8", UInt32(kVK_ANSI_9): "9"
    ]
}

enum ShortcutValidationError: Error, Equatable, Sendable {
    case unsupportedKey
    case insufficientModifiers
    case conflict
}

enum ShortcutPolicy {
    static func validate(
        _ shortcut: ShortcutDescriptor,
        conflictingWith conflicts: Set<ShortcutDescriptor> = []
    ) -> Result<Void, ShortcutValidationError> {
        guard ShortcutDescriptor.isSupportedKeyCode(shortcut.keyCode) else {
            return .failure(.unsupportedKey)
        }
        guard shortcut.modifiers.count >= 2,
              !shortcut.modifiers.intersection([.command, .control, .option]).isEmpty else {
            return .failure(.insufficientModifiers)
        }
        guard !conflicts.contains(shortcut) else {
            return .failure(.conflict)
        }
        return .success(())
    }

    static func validationError(
        for shortcut: ShortcutDescriptor,
        conflictingWith conflicts: Set<ShortcutDescriptor> = []
    ) -> String? {
        switch validate(shortcut, conflictingWith: conflicts) {
        case .success:
            return nil
        case .failure(.unsupportedKey):
            return "Используйте букву A–Z или цифру 0–9"
        case .failure(.insufficientModifiers):
            return "Нужно сочетание минимум с двумя модификаторами"
        case .failure(.conflict):
            return "Это сочетание уже используется другим действием NeClip"
        }
    }
}
