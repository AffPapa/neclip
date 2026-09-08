import AppKit
import Combine
import XCTest
@testable import NeClip

final class PreferencesNavigationTests: XCTestCase {
    func testNumericInputIsClampedOnlyWhenCommitted() {
        XCTAssertEqual(NumericPreferenceInput.normalized(" 64 ", current: 32, range: 16...96), 64)
        XCTAssertEqual(NumericPreferenceInput.normalized("4", current: 32, range: 16...96), 16)
        XCTAssertEqual(NumericPreferenceInput.normalized("999", current: 32, range: 16...96), 96)
        for invalid in ["", "abc", "64.5", String(repeating: "9", count: 100)] {
            XCTAssertEqual(NumericPreferenceInput.normalized(invalid, current: 32, range: 16...96), 32)
        }
    }

    func testToolbarHasStableDistinctCategoriesAndSymbols() async {
        await MainActor.run {
            let controller = PreferencesWindowController()
            let toolbar = NSToolbar(identifier: "test")
            let identifiers = controller.toolbarDefaultItemIdentifiers(toolbar)
            XCTAssertEqual(identifiers.count, 3)
            XCTAssertEqual(Set(identifiers).count, 3)
            XCTAssertEqual(identifiers, PreferencesSection.visibleSections.map(\.identifier))
            XCTAssertFalse(identifiers.contains(PreferencesSection.version.identifier))
            XCTAssertFalse(identifiers.contains(PreferencesSection.privacy.identifier))
            XCTAssertFalse(identifiers.contains(PreferencesSection.layout.identifier))
            XCTAssertFalse(identifiers.contains(PreferencesSection.data.identifier))
            XCTAssertEqual(controller.toolbarSelectableItemIdentifiers(toolbar), identifiers)
            for section in PreferencesSection.allCases {
                XCTAssertEqual(section.windowTitle, "\(RuntimeIdentity.displayName) — \(section.title)")
                let item = controller.toolbar(toolbar, itemForItemIdentifier: section.identifier,
                                              willBeInsertedIntoToolbar: true)
                XCTAssertEqual(item?.label, section.title)
                XCTAssertNotNil(item?.image)
                XCTAssertTrue(item?.target === controller)
                XCTAssertNotNil(item?.action)
            }
            XCTAssertNil(controller.toolbar(toolbar, itemForItemIdentifier: .init("unknown"),
                                            willBeInsertedIntoToolbar: true))
        }
    }

    func testDraftCommitPrecedesSectionChangeAndClose() async {
        await MainActor.run {
            let controller = PreferencesWindowController()
            var observed: [PreferencesSection] = []
            let subscription = controller.navigation.commitEdits.sink {
                observed.append(controller.navigation.selected)
            }
            controller.navigation.select(.data)
            XCTAssertEqual(observed, [.general])
            XCTAssertEqual(controller.navigation.selected, .data)
            controller.commitPendingEdits()
            XCTAssertEqual(observed, [.general, .data])
            withExtendedLifetime(subscription) {}
        }
    }

    func testSettingsKeepResizableAccessibleChromeWithoutMinimizeOrZoom() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(contentsOf: root.appendingPathComponent("Sources/NeClip/PreferencesWindow.swift"), encoding: .utf8)
        XCTAssertTrue(source.contains("window.styleMask = [.titled, .closable, .resizable]"))
        XCTAssertTrue(source.contains("standardWindowButton(.miniaturizeButton)?.isEnabled = false"))
        XCTAssertTrue(source.contains("standardWindowButton(.zoomButton)?.isEnabled = false"))
        XCTAssertTrue(source.contains("window?.title = section.windowTitle"))
        XCTAssertFalse(source.contains("⌥ — изменить режим форматирования"))
        XCTAssertFalse(source.contains("⌥ — просмотреть выбранное"))
        XCTAssertTrue(source.contains("DisclosureGroup(isExpanded: $layoutMemoryExpanded)"))
    }
}
