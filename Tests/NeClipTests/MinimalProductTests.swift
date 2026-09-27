import AppKit
import XCTest
@testable import NeClip

final class MinimalProductTests: XCTestCase {
    func testUpgradeRemovesRetiredPreferencesWithoutResettingClipboardSettings() throws {
        let suite = "org.affpapa.neclip.tests.retired.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let retired = [
            "automaticLayoutCorrection", "manualCorrectionOptionKey", "layoutExcludedApps",
            "rememberLayoutPerApplication", "applicationLayoutMemory.v1",
            "applicationLayoutMemoryOrder.v1", "fixedApplicationLayouts.v1",
            "fixedApplicationLayoutOrder.v1", "screenshotFormat", "screenshotFolderBookmark.v1",
            "screenshotShortcut.v1", "fullScreenScreenshotShortcut.v1",
            "manualLayoutShortcut.v1", "disableAutomaticLayoutShortcut.v1"
        ]
        retired.forEach { defaults.set(Data([1, 2, 3]), forKey: $0) }
        let retained: [String: Any] = [
            "historyLimit": 350, "captureImages": true, "excludedApps": ["com.example.private"],
            "historyShortcut.v1": Data([4]), "snippetsShortcut.v1": Data([5]),
            "sequentialPasteShortcut.v1": Data([6]), "capturePausedIndefinitely": true,
            "preferPlainText": true, "onboardingCompletedV2": true, "onboardingClipboardCompletedV3": true, "futurePreference": "keep"
        ]
        retained.forEach { defaults.set($0.value, forKey: $0.key) }
        for _ in 0..<2 {
            Settings.removeRetiredPreferences(from: defaults)
            retired.forEach { XCTAssertNil(defaults.object(forKey: $0), $0) }
            XCTAssertEqual(defaults.persistentDomain(forName: suite) as NSDictionary?, retained as NSDictionary)
        }
    }

    @MainActor
    func testOnlyClipboardShortcutsRegisterAndRetiredChordsAreAvailable() {
        let registry = FakeHotKeyRegistry()
        let actions = NeClipShortcutAction.allCases
        XCTAssertEqual(actions, [.history, .snippets, .sequentialPaste])
        let coordinator = HotKeyCoordinator(
            registrationFactory: registry,
            initialShortcuts: Dictionary(uniqueKeysWithValues: actions.map { ($0, $0.defaultShortcut) }),
            persistsSettings: false
        )
        coordinator.start(historyAction: {}, snippetsAction: {}, sequentialPasteAction: {})
        XCTAssertEqual(registry.active.count, 3)
        // Previously reserved by screenshot and manual correction actions.
        for chord in [ShortcutDescriptor(keyCode: 19, modifiers: [.command, .shift]),
                      ShortcutDescriptor(keyCode: 37, modifiers: [.option, .shift])] {
            XCTAssertEqual(coordinator.update(.history, to: chord), .applied)
            XCTAssertEqual(registry.active.count, 3)
        }
        let footer = NSMenu()
        StatusBarController.appendStandardFooter(to: footer, target: NSObject())
        XCTAssertEqual(footer.items.filter { !$0.isSeparatorItem }.map(\.title), ["Настройки…", "Выйти из NeClip"])
    }

    func testRuntimeContainsNoScreenCaptureKeyboardMonitoringOrInputSourceSwitching() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources/NeClip")
        let files = try FileManager.default.contentsOfDirectory(at: sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        let source = try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
        for forbidden in ["import ScreenCaptureKit", "SCShareableContent", "CGRequestScreenCaptureAccess",
                          "CGPreflightScreenCaptureAccess", "CGRequestListenEventAccess", "CGEvent.tapCreate",
                          "TISSelectInputSource", "TISCopyCurrentKeyboardInputSource", "ScreenshotCoordinator",
                          "KeyboardLayoutService", "LayoutPermissions"] {
            XCTAssertFalse(source.contains(forbidden), forbidden)
        }
        XCTAssertTrue(source.contains("AXIsProcessTrusted"))
        XCTAssertTrue(source.contains("static var captureImages"))
    }
}
