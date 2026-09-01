import AppKit
import XCTest
@testable import NeClip

final class ClipboardInteractionTests: XCTestCase {
    func testTextMergeUsesOneSeparatorWithoutDuplicatingExistingNewlines() {
        XCTAssertEqual(ClipboardTextMerge.join("alpha", "beta"), "alpha\nbeta")
        XCTAssertEqual(ClipboardTextMerge.join("alpha\n", "beta"), "alpha\nbeta")
        XCTAssertEqual(ClipboardTextMerge.join("alpha", "\nbeta"), "alpha\nbeta")
        XCTAssertEqual(ClipboardTextMerge.join("", "beta"), "beta")
    }

    func testTextMergeTitleIsBoundedAndSingleLine() {
        let title = ClipboardTextMerge.title(for: "  first\r\nsecond  ")
        XCTAssertEqual(title, "first  second")
        XCTAssertLessThanOrEqual(title.count, 200)
    }

    func testSpacePreviewNeverStealsARealSearchSpace() {
        XCTAssertTrue(MenuSearchKeyPolicy.shouldPreviewOnSpace(
            keyCode: 49,
            modifiers: [],
            searchText: "",
            isRepeat: false
        ))
        XCTAssertFalse(MenuSearchKeyPolicy.shouldPreviewOnSpace(
            keyCode: 49,
            modifiers: [],
            searchText: "two words",
            isRepeat: false
        ))
        XCTAssertFalse(MenuSearchKeyPolicy.shouldPreviewOnSpace(
            keyCode: 49,
            modifiers: .command,
            searchText: "",
            isRepeat: false
        ))
        XCTAssertFalse(MenuSearchKeyPolicy.shouldPreviewOnSpace(
            keyCode: 49,
            modifiers: [],
            searchText: "",
            isRepeat: true
        ))
    }
}
