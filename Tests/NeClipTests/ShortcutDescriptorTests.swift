import AppKit
import Carbon.HIToolbox
import XCTest
@testable import NeClip

final class ShortcutDescriptorTests: XCTestCase {
    func testDefaultsPreserveLegacyManualAndProvideOffOnlySafetyShortcut() {
        XCTAssertEqual(ShortcutDescriptor.snippetsDefault.keyCode, UInt32(kVK_ANSI_B))
        XCTAssertEqual(ShortcutDescriptor.snippetsDefault.modifiers, [.command, .shift])
        XCTAssertEqual(ShortcutDescriptor.snippetsDefault.displayName, "⇧⌘B")

        XCTAssertEqual(ShortcutDescriptor.defaultManualLayout.keyCode, UInt32(kVK_ANSI_L))
        XCTAssertEqual(ShortcutDescriptor.defaultManualLayout.modifiers, [.option, .shift])
        XCTAssertEqual(ShortcutDescriptor.defaultManualLayout.displayName, "⌥⇧L")

        XCTAssertEqual(ShortcutDescriptor.defaultDisableAutomaticLayout.keyCode, UInt32(kVK_ANSI_A))
        XCTAssertEqual(ShortcutDescriptor.defaultDisableAutomaticLayout.modifiers, [.control, .option])
        XCTAssertEqual(ShortcutDescriptor.defaultDisableAutomaticLayout.displayName, "⌃⌥A")
    }

    func testDescriptorCodableRoundTripIsExact() throws {
        let original = ShortcutDescriptor(
            keyCode: UInt32(kVK_ANSI_7),
            modifiers: [.control, .option, .shift]
        )
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(ShortcutDescriptor.self, from: data), original)
    }

    func testModifierDecoderRejectsUnknownPersistentBits() throws {
        let data = try XCTUnwrap("255".data(using: .utf8))
        XCTAssertThrowsError(try JSONDecoder().decode(ShortcutModifiers.self, from: data))
    }

    func testFrameworkConversionsNormalizeIrrelevantFlags() {
        let modifiers: ShortcutModifiers = [.command, .control, .option, .shift]
        XCTAssertEqual(ShortcutModifiers(carbonModifiers: modifiers.carbonModifiers), modifiers)
        XCTAssertEqual(ShortcutModifiers(cgEventFlags: modifiers.cgEventFlags), modifiers)
        XCTAssertEqual(ShortcutModifiers(nsEventFlags: modifiers.nsEventFlags), modifiers)

        let appKitWithNoise: NSEvent.ModifierFlags = [
            .command, .option, .capsLock, .function, .numericPad
        ]
        XCTAssertEqual(ShortcutModifiers(nsEventFlags: appKitWithNoise), [.command, .option])

        let cgWithNoise: CGEventFlags = [.maskControl, .maskShift, .maskAlphaShift, .maskNumericPad]
        XCTAssertEqual(ShortcutModifiers(cgEventFlags: cgWithNoise), [.control, .shift])
    }

    func testExactMatcherRejectsARecognizedExtraModifierButIgnoresCapsLock() {
        let shortcut = ShortcutDescriptor.defaultManualLayout
        XCTAssertTrue(shortcut.matches(
            keyCode: UInt16(kVK_ANSI_L),
            cgEventFlags: [.maskAlternate, .maskShift]
        ))
        XCTAssertTrue(shortcut.matches(
            keyCode: UInt16(kVK_ANSI_L),
            cgEventFlags: [.maskAlternate, .maskShift, .maskAlphaShift]
        ))
        XCTAssertFalse(shortcut.matches(
            keyCode: UInt16(kVK_ANSI_L),
            cgEventFlags: [.maskAlternate, .maskShift, .maskCommand]
        ))
        XCTAssertFalse(shortcut.matches(
            keyCode: UInt16(kVK_ANSI_K),
            cgEventFlags: [.maskAlternate, .maskShift]
        ))
    }

    func testPolicyAcceptsDefaultsAndSupportedPhysicalKeys() {
        XCTAssertNil(ShortcutPolicy.validationError(for: .defaultManualLayout))
        XCTAssertNil(ShortcutPolicy.validationError(for: .defaultDisableAutomaticLayout))

        for keyCode in [
            kVK_ANSI_A, kVK_ANSI_M, kVK_ANSI_Z,
            kVK_ANSI_0, kVK_ANSI_5, kVK_ANSI_9
        ] {
            let shortcut = ShortcutDescriptor(
                keyCode: UInt32(keyCode),
                modifiers: [.control, .shift]
            )
            XCTAssertNil(ShortcutPolicy.validationError(for: shortcut), shortcut.displayName)
        }
    }

    func testPolicyRejectsInsufficientUnsupportedAndConflictingShortcuts() {
        let oneModifier = ShortcutDescriptor(
            keyCode: UInt32(kVK_ANSI_L),
            modifiers: [.command]
        )
        assertValidationFailure(oneModifier, equals: .insufficientModifiers)

        let shiftOnly = ShortcutDescriptor(
            keyCode: UInt32(kVK_ANSI_L),
            modifiers: [.shift]
        )
        assertValidationFailure(shiftOnly, equals: .insufficientModifiers)

        let unsupported = ShortcutDescriptor(
            keyCode: UInt32(kVK_Escape),
            modifiers: [.control, .option]
        )
        assertValidationFailure(unsupported, equals: .unsupportedKey)

        XCTAssertNil(ShortcutPolicy.validationError(for: .historyDefault))
        switch ShortcutPolicy.validate(.historyDefault, conflictingWith: [.historyDefault]) {
        case .success:
            XCTFail("Expected conflict validation to fail")
        case .failure(let actual):
            XCTAssertEqual(actual, .conflict)
        }
    }

    func testDisplayAndMenuEquivalentUsePhysicalKeyLabel() {
        let shortcut = ShortcutDescriptor(
            keyCode: UInt32(kVK_ANSI_Q),
            modifiers: [.control, .option, .shift, .command]
        )
        XCTAssertEqual(shortcut.displayString, "⌃⌥⇧⌘Q")
        XCTAssertEqual(shortcut.keyEquivalent, "q")

        let unsupported = ShortcutDescriptor(
            keyCode: UInt32(kVK_Return),
            modifiers: [.control, .option]
        )
        XCTAssertEqual(unsupported.displayString, "⌃⌥?")
        XCTAssertNil(unsupported.keyEquivalent)
    }

    private func assertValidationFailure(
        _ shortcut: ShortcutDescriptor,
        equals expected: ShortcutValidationError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch ShortcutPolicy.validate(shortcut) {
        case .success:
            XCTFail("Expected validation to fail", file: file, line: line)
        case .failure(let actual):
            XCTAssertEqual(actual, expected, file: file, line: line)
        }
    }
}
