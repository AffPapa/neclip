import XCTest
@testable import NeClip

final class AuditRegressionTests: XCTestCase {
    func testMenuDefersFolderTargetsUntilTheSpecificActionMenuOpens() {
        XCTAssertEqual(MenuMaterializationPolicy.visibleHistoryCount(clipCount: 1_000, requestedVisibleCount: 10), 10)
        XCTAssertEqual(MenuMaterializationPolicy.overflowRange(clipCount: 1_000, requestedVisibleCount: 10), 10..<1_000)
        XCTAssertTrue(MenuMaterializationPolicy.overflowRange(clipCount: 10, requestedVisibleCount: 10).isEmpty)
        XCTAssertEqual(
            MenuMaterializationPolicy.openedActionItemCount(folderCount: 200, includesOpenTarget: true),
            206
        )
    }

    func testTemporarySelectionIsRestoredOnlyWhenNeClipStillOwnsIt() {
        let caret = CFRange(location: 6, length: 0)
        let selectedWord = CFRange(location: 0, length: 6)
        XCTAssertTrue(LayoutSelectionRestorationPolicy.shouldRestore(
            caret: caret, temporarySelection: selectedWord, currentSelection: selectedWord,
            currentText: "ghbdtn", expectedText: "ghbdtn"
        ))
        XCTAssertFalse(LayoutSelectionRestorationPolicy.shouldRestore(
            caret: caret, temporarySelection: selectedWord, currentSelection: caret,
            currentText: "ghbdtn", expectedText: "ghbdtn"
        ))
        XCTAssertFalse(LayoutSelectionRestorationPolicy.shouldRestore(
            caret: caret, temporarySelection: selectedWord, currentSelection: selectedWord,
            currentText: "changed", expectedText: "ghbdtn"
        ))
    }
}
