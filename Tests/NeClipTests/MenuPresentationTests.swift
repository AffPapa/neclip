import AppKit
import XCTest
@testable import NeClip

final class MenuPresentationTests: XCTestCase {
    func testExactLimitDoesNotAddEllipsis() {
        let value = String(repeating: "я", count: 32)

        XCTAssertEqual(MenuTitleFormatter.format(value, limit: 32), value)
    }

    func testOneCharacterPastLimitAddsEllipsisAfterExactlyNCharacters() {
        let value = String(repeating: "я", count: 33)

        XCTAssertEqual(
            MenuTitleFormatter.format(value, limit: 32),
            String(repeating: "я", count: 32) + "…"
        )
    }

    func testAllWhitespaceRunsCollapseAndEdgesAreTrimmed() {
        let value = " \r\n  Привет\t\tмир\u{2028}\u{2029}снова  \n "

        XCTAssertEqual(
            MenuTitleFormatter.format(value, limit: 64),
            "Привет мир снова"
        )
    }

    func testUnicodeGraphemeClustersAreNotSplit() {
        let family = "👨‍👩‍👧‍👦"
        let combiningE = "e\u{301}"
        let prefix = family + combiningE + String(repeating: "界", count: 14)
        let value = prefix + "文"

        XCTAssertEqual(prefix.count, 16)
        XCTAssertEqual(value.count, 17)
        XCTAssertEqual(MenuTitleFormatter.format(value, limit: 16), prefix + "…")
    }

    func testUserFacingLengths32And64() {
        let value = String(repeating: "Ж", count: 80)

        XCTAssertEqual(
            MenuTitleFormatter.format(value, limit: 32),
            String(repeating: "Ж", count: 32) + "…"
        )
        XCTAssertEqual(
            MenuTitleFormatter.format(value, limit: 64),
            String(repeating: "Ж", count: 64) + "…"
        )
    }

    func testLengthClampsToSupportedRange() {
        XCTAssertEqual(MenuTitleFormatter.defaultLength, 64)
        XCTAssertEqual(MenuTitleFormatter.clampedLength(Int.min), 16)
        XCTAssertEqual(MenuTitleFormatter.clampedLength(32), 32)
        XCTAssertEqual(MenuTitleFormatter.clampedLength(Int.max), 96)

        let value = String(repeating: "x", count: 100)
        XCTAssertEqual(
            MenuTitleFormatter.format(value, limit: 0),
            String(repeating: "x", count: 16) + "…"
        )
        XCTAssertEqual(
            MenuTitleFormatter.format(value, limit: 1_000),
            String(repeating: "x", count: 96) + "…"
        )
    }

    func testWhitespaceOnlyInputBecomesEmptyWithoutEllipsis() {
        XCTAssertEqual(
            MenuTitleFormatter.format("\t\r\n\u{2028}\u{2029} ", limit: 32),
            ""
        )
    }

    @MainActor
    func testAppearanceAppliesRecursivelyToSubmenusAndCustomViews() throws {
        let appearance = try XCTUnwrap(NSAppearance(named: .darkAqua))
        let root = NSMenu(title: "Root")
        let child = NSMenu(title: "Child")
        let grandchild = NSMenu(title: "Grandchild")
        let customView = NSView()

        let childItem = NSMenuItem(title: "Child", action: nil, keyEquivalent: "")
        childItem.view = customView
        childItem.submenu = child
        root.addItem(childItem)

        let grandchildItem = NSMenuItem(title: "Grandchild", action: nil, keyEquivalent: "")
        grandchildItem.submenu = grandchild
        child.addItem(grandchildItem)

        MenuAppearance.apply(appearance, to: root)

        XCTAssertEqual(root.appearance?.name, .darkAqua)
        XCTAssertEqual(child.appearance?.name, .darkAqua)
        XCTAssertEqual(grandchild.appearance?.name, .darkAqua)
        XCTAssertEqual(customView.appearance?.name, .darkAqua)
    }

    @MainActor
    func testEffectiveAppearanceHelperUsesApplicationAppearance() {
        let menu = NSMenu(title: "Root")

        MenuAppearance.applyEffectiveAppearance(to: menu)

        XCTAssertEqual(
            menu.appearance?.bestMatch(from: [.aqua, .darkAqua]),
            NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        )
    }
}
