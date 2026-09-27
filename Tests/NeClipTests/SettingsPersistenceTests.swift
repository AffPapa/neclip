import Foundation
import XCTest
@testable import NeClip

final class SettingsPersistenceTests: XCTestCase {
    private let shortcutKeys: [(NeClipShortcutAction, String)] = [
        (.history, "historyShortcut.v1"),
        (.snippets, "snippetsShortcut.v1"),
        (.sequentialPaste, "sequentialPasteShortcut.v1"),
    ]
    private var saved: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        for key in shortcutKeys.map(\.1) {
            saved[key] = UserDefaults.standard.object(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
        drainNotifications()
    }

    override func tearDown() {
        drainNotifications()
        for key in shortcutKeys.map(\.1) {
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
    }

    private func drainNotifications() {
        let drained = expectation(description: "Earlier notifications drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
    }
}
