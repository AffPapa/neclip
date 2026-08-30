import XCTest
@testable import NeClip

final class LayoutCorrectionTests: XCTestCase {
    private var maps: LayoutCharacterMaps {
        let english = Array("qwertyuiop[]asdfghjkl;'zxcvbnm,.")
        let russian = Array("йцукенгшщзхъфывапролджэячсмитьбю")
        var enToRu: [Character: Character] = [:]
        var ruToEn: [Character: Character] = [:]
        for (en, ru) in zip(english, russian) {
            enToRu[en] = ru
            ruToEn[ru] = en
            if en.isLetter, ru.isLetter,
               let upperEN = en.uppercased().first,
               let upperRU = ru.uppercased().first {
                enToRu[upperEN] = upperRU
                ruToEn[upperRU] = upperEN
            }
        }
        return LayoutCharacterMaps(
            englishToRussian: enToRu,
            russianToEnglish: ruToEn,
            englishSourceID: "en",
            russianSourceID: "ru"
        )
    }

    func testManualConversionWorksBothDirections() {
        XCTAssertEqual(maps.convert("ghbdtn")?.converted, "привет")
        XCTAssertEqual(maps.convert("руддщ")?.converted, "hello")
        XCTAssertEqual(maps.convert("ghbdtn")?.direction, .englishToRussian)
        XCTAssertEqual(maps.convert("руддщ")?.direction, .russianToEnglish)
    }

    func testManualConversionPreservesCaseAndLiteralTrailingPunctuation() {
        XCTAssertEqual(maps.convert("Ghbdtn,")?.converted, "Привет,")
        XCTAssertEqual(maps.convert("РУДДЩ!")?.converted, "HELLO!")
    }

    func testManualConversionFailsClosedForMixedScriptsOrNoLetters() {
        XCTAssertNil(maps.convert("ghbdтn"))
        XCTAssertNil(maps.convert("1234?!"))
        XCTAssertNil(maps.convert(""))
    }

    func testAutoDecisionRequiresOnlyConvertedWordToBeKnown() {
        XCTAssertEqual(AutoLayoutDecisionPolicy.decide(
            typed: "ghbdtn",
            converted: "привет",
            typedIsKnownWord: false,
            convertedIsKnownWord: true
        ), .correct)
        XCTAssertEqual(AutoLayoutDecisionPolicy.decide(
            typed: "hello",
            converted: "руддщ",
            typedIsKnownWord: true,
            convertedIsKnownWord: false
        ), .stay)
        XCTAssertEqual(AutoLayoutDecisionPolicy.decide(
            typed: "name",
            converted: "тфьу",
            typedIsKnownWord: true,
            convertedIsKnownWord: true
        ), .stay)
    }

    func testAutoDecisionRejectsShortAllCapsCodeAndStructuredTokens() {
        for token in ["abc", "APIX", "myVar", "mail@example.com", "path/to/file", "abc123"] {
            XCTAssertFalse(LayoutTextPolicy.isAutoCandidate(token), token)
        }
        XCTAssertTrue(LayoutTextPolicy.isAutoCandidate("ghbdtn"))
    }

    func testTypingBufferBackspaceBoundaryAndReset() {
        var buffer = AutoTypingBuffer(capacity: 4)
        XCTAssertTrue(buffer.append(LayoutTypedStroke(keyCode: 1, shift: false, capsLock: false)))
        XCTAssertTrue(buffer.append(LayoutTypedStroke(keyCode: 2, shift: true, capsLock: false)))
        buffer.backspace()
        XCTAssertEqual(buffer.takeAtBoundary(), [LayoutTypedStroke(keyCode: 1, shift: false, capsLock: false)])
        XCTAssertTrue(buffer.strokes.isEmpty)
    }

    func testTypingBufferOverflowDropsTheWholeToken() {
        var buffer = AutoTypingBuffer(capacity: 2)
        XCTAssertTrue(buffer.append(LayoutTypedStroke(keyCode: 1, shift: false, capsLock: false)))
        XCTAssertTrue(buffer.append(LayoutTypedStroke(keyCode: 2, shift: false, capsLock: false)))
        XCTAssertFalse(buffer.append(LayoutTypedStroke(keyCode: 3, shift: false, capsLock: false)))
        XCTAssertTrue(buffer.strokes.isEmpty)
    }

    func testWholeValueCASNeverRollsBackOverConcurrentMutation() {
        XCTAssertTrue(LayoutWholeValueCASPolicy.shouldRollback(
            currentValue: "привет ",
            ownReplacement: "привет "
        ))
        XCTAssertFalse(LayoutWholeValueCASPolicy.shouldRollback(
            currentValue: "привет x",
            ownReplacement: "привет "
        ))
        XCTAssertFalse(LayoutWholeValueCASPolicy.shouldRollback(
            currentValue: nil,
            ownReplacement: "привет "
        ))
    }

    func testProtectedApplicationsCannotBeRemovedThroughUserExclusions() {
        XCTAssertTrue(LayoutProtectedApplicationPolicy.blocksAutomatic(bundleID: nil, userExcluded: []))
        XCTAssertTrue(LayoutProtectedApplicationPolicy.blocksAutomatic(
            bundleID: "com.1password.1password",
            userExcluded: []
        ))
        XCTAssertTrue(LayoutProtectedApplicationPolicy.blocksAutomatic(
            bundleID: "com.jetbrains.rider",
            userExcluded: []
        ))
        XCTAssertTrue(LayoutProtectedApplicationPolicy.blocksAutomatic(
            bundleID: "com.example.editor",
            userExcluded: ["com.example.editor"]
        ))
        XCTAssertFalse(LayoutProtectedApplicationPolicy.blocksAutomatic(
            bundleID: "com.apple.TextEdit",
            userExcluded: []
        ))
        XCTAssertFalse(LayoutProtectedApplicationPolicy.blocksManual(bundleID: "com.apple.dt.Xcode"))
        XCTAssertTrue(LayoutProtectedApplicationPolicy.blocksManual(bundleID: "com.bitwarden.desktop"))
    }

    func testAutomaticCorrectionSettingCanAlwaysBeTurnedOff() {
        let previous = Settings.automaticLayoutCorrection
        defer { Settings.automaticLayoutCorrection = previous }
        Settings.automaticLayoutCorrection = true
        XCTAssertTrue(Settings.automaticLayoutCorrection)
        Settings.automaticLayoutCorrection = false
        XCTAssertFalse(Settings.automaticLayoutCorrection)
    }

    func testClipboardAndLayoutExclusionsStayIndependent() {
        let oldClipboard = Settings.excludedApps
        let oldLayout = Settings.layoutExcludedApps
        defer {
            Settings.excludedApps = oldClipboard
            Settings.layoutExcludedApps = oldLayout
        }
        Settings.excludedApps = ["com.example.clipboard"]
        Settings.layoutExcludedApps = ["com.example.layout"]
        XCTAssertEqual(Settings.excludedApps, ["com.example.clipboard"])
        XCTAssertEqual(Settings.layoutExcludedApps, ["com.example.layout"])
    }

    @MainActor
    func testEnabledSystemLayoutsConvertCommonPairWhenAvailable() throws {
        let service = KeyboardLayoutService.shared
        service.invalidate()
        guard service.layoutPair() != nil else {
            throw XCTSkip("Enabled English and Russian system keyboard layouts are required")
        }
        XCTAssertEqual(service.convert("ghbdtn")?.converted, "привет")
        XCTAssertEqual(service.convert("руддщ")?.converted, "hello")
    }

    @MainActor
    func testExactEnabledSourceCanBeReselectedAfterCacheInvalidation() throws {
        let service = KeyboardLayoutService.shared
        guard let originalID = service.currentSourceID() else {
            throw XCTSkip("A direct keyboard-layout input source is required")
        }
        service.invalidate()
        XCTAssertTrue(service.selectSource(id: originalID))
        XCTAssertEqual(service.currentSourceID(), originalID)
    }
}
