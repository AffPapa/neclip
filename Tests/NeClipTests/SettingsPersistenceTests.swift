import Foundation
import XCTest
@testable import NeClip

final class SettingsPersistenceTests: XCTestCase {
    private let shortcutKeys: [(NeClipShortcutAction, String)] = [
        (.history, "historyShortcut.v1"),
        (.snippets, "snippetsShortcut.v1"),
        (.screenshot, "screenshotShortcut.v1"),
        (.fullScreenScreenshot, "fullScreenScreenshotShortcut.v1"),
        (.sequentialPaste, "sequentialPasteShortcut.v1"),
        (.manualCorrection, "manualLayoutShortcut.v1"),
        (.disableAutomaticCorrection, "disableAutomaticLayoutShortcut.v1")
    ]
    private let layoutKeys = [
        "applicationLayoutMemory.v1", "applicationLayoutMemoryOrder.v1",
        "fixedApplicationLayouts.v1", "fixedApplicationLayoutOrder.v1"
    ]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in layoutKeys + shortcutKeys.map(\.1) {
            saved[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
        drainNotifications()
    }

    override func tearDown() {
        drainNotifications()
        for key in layoutKeys + shortcutKeys.map(\.1) {
            if let value = saved[key] {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        saved.removeAll()
        super.tearDown()
    }

    func testShortcutsReadAndWriteExistingKeysAndRejectInvalidValues() throws {
        let candidate = ShortcutDescriptor(keyCode: 0, modifiers: [.control, .option, .shift])
        let encoded = try JSONEncoder().encode(candidate)
        let invalid = ShortcutDescriptor(keyCode: 0, modifiers: [])
        for (action, key) in shortcutKeys {
            XCTAssertEqual(action.persistedShortcut, action.defaultShortcut)
            UserDefaults.standard.set(encoded, forKey: key)
            XCTAssertEqual(action.persistedShortcut, candidate)
            Settings.storeShortcut(action.defaultShortcut, for: action)
            let stored = try XCTUnwrap(UserDefaults.standard.data(forKey: key))
            XCTAssertEqual(try JSONDecoder().decode(ShortcutDescriptor.self, from: stored), action.defaultShortcut)
            Settings.storeShortcut(invalid, for: action)
            XCTAssertEqual(UserDefaults.standard.data(forKey: key), stored)
            UserDefaults.standard.set(Data("invalid JSON".utf8), forKey: key)
            XCTAssertEqual(action.persistedShortcut, action.defaultShortcut)
            UserDefaults.standard.set(try JSONEncoder().encode(invalid), forKey: key)
            XCTAssertEqual(action.persistedShortcut, action.defaultShortcut)
        }
        XCTAssertEqual(Settings.historyShortcut, NeClipShortcutAction.history.defaultShortcut)
        XCTAssertEqual(Settings.snippetsShortcut, NeClipShortcutAction.snippets.defaultShortcut)
        XCTAssertEqual(Settings.sequentialPasteShortcut, NeClipShortcutAction.sequentialPaste.defaultShortcut)
        XCTAssertEqual(Settings.manualLayoutShortcut, NeClipShortcutAction.manualCorrection.defaultShortcut)
        XCTAssertEqual(Settings.disableAutomaticLayoutShortcut, NeClipShortcutAction.disableAutomaticCorrection.defaultShortcut)
    }

    func testBothLayoutMapsPreserveRecencyEvictionAndInvalidInputIsANoOp() {
        let keys = (0..<200).map { "com.example.app.\($0)" }
        let initial = Dictionary(uniqueKeysWithValues: keys.map { ($0, "source.original") })
        let stores: [(String, String, (String, String) -> Void)] = [
            (layoutKeys[0], layoutKeys[1], { Settings.rememberLayoutSource($0, for: $1) }),
            (layoutKeys[2], layoutKeys[3], { Settings.setFixedLayoutSource($0, for: $1) })
        ]
        for (valueKey, orderKey, store) in stores {
            UserDefaults.standard.set(initial, forKey: valueKey)
            UserDefaults.standard.set(keys, forKey: orderKey)
            store(" source.refreshed ", " \(keys[0]) ")
            store("source.new", "com.example.new")
            let mapping = UserDefaults.standard.dictionary(forKey: valueKey) as? [String: String]
            let order = UserDefaults.standard.stringArray(forKey: orderKey)
            XCTAssertEqual(mapping?.count, 200)
            XCTAssertEqual(mapping?[keys[0]], "source.refreshed")
            XCTAssertNil(mapping?[keys[1]])
            XCTAssertEqual(order, Array(keys.dropFirst(2)) + [keys[0], "com.example.new"])
            for (source, bundle) in [
                (" ", keys[0]), (String(repeating: "x", count: 513), keys[0]),
                ("source", " "), ("source", String(repeating: "x", count: 256))
            ] {
                store(source, bundle)
            }
            XCTAssertEqual(UserDefaults.standard.dictionary(forKey: valueKey) as? [String: String], mapping)
            XCTAssertEqual(UserDefaults.standard.stringArray(forKey: orderKey), order)
        }
        Settings.setFixedLayoutSource(nil, for: " \(keys[0]) ")
        XCTAssertNil(Settings.fixedLayoutSource(for: keys[0]))
        XCTAssertEqual(Settings.rememberedLayoutSource(for: keys[0]), "source.refreshed")
        XCTAssertFalse(UserDefaults.standard.stringArray(forKey: layoutKeys[3])?.contains(keys[0]) ?? true)
    }

    func testRememberedChangesNotifyMemoryWithoutEnablingLayoutObservers() {
        let memory = expectation(forNotification: .neClipApplicationLayoutMemoryDidChange, object: nil) { _ in
            XCTAssertTrue(Thread.isMainThread)
            return true
        }
        memory.expectedFulfillmentCount = 2
        let layout = expectation(forNotification: .neClipLayoutSettingsDidChange, object: nil)
        layout.isInverted = true
        Settings.rememberLayoutSource("source.en", for: "com.example.editor")
        Settings.clearRememberedApplicationLayouts()
        Settings.rememberLayoutSource(" ", for: "com.example.editor")
        wait(for: [memory, layout], timeout: 0.1)
        XCTAssertNil(UserDefaults.standard.object(forKey: layoutKeys[0]))
        XCTAssertNil(UserDefaults.standard.object(forKey: layoutKeys[1]))
    }

    func testFixedWriteRemovalAndClearNotifyBothDomains() {
        let memory = expectation(forNotification: .neClipApplicationLayoutMemoryDidChange, object: nil)
        let layout = expectation(forNotification: .neClipLayoutSettingsDidChange, object: nil) { _ in
            XCTAssertTrue(Thread.isMainThread)
            return true
        }
        memory.expectedFulfillmentCount = 3
        layout.expectedFulfillmentCount = 3
        Settings.setFixedLayoutSource("source.en", for: "com.example.editor")
        Settings.setFixedLayoutSource(nil, for: "com.example.editor")
        Settings.clearFixedApplicationLayouts()
        Settings.setFixedLayoutSource(" ", for: "com.example.editor")
        let drained = expectation(description: "Notifications drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [memory, layout, drained], timeout: 1)
        XCTAssertNil(UserDefaults.standard.object(forKey: layoutKeys[2]))
        XCTAssertNil(UserDefaults.standard.object(forKey: layoutKeys[3]))
    }

    private func drainNotifications() {
        let drained = expectation(description: "Earlier notifications drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}
