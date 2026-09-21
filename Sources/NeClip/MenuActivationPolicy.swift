import AppKit

enum MenuActivationPolicy {
    /// Cmd belongs to a numeric quick shortcut only when that shortcut actually
    /// activated the item. A Cmd-Return or Cmd-click on the very same item means
    /// copy-only, and must not silently turn into an automatic paste.
    static func modifiers(keyEquivalent: String, characters: String?, isKeyDown: Bool,
                          modifiers: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        guard isKeyDown, !keyEquivalent.isEmpty, characters == keyEquivalent,
              modifiers.contains(.command) else { return modifiers }
        return modifiers.subtracting(.command)
    }
}
