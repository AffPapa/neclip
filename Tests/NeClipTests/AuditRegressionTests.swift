import XCTest
@testable import NeClip

final class AuditRegressionTests: XCTestCase {
    func testMenuDefersFolderTargetsUntilTheSpecificActionMenuOpens() {
        XCTAssertEqual(MenuMaterializationPolicy.eagerItemCount(clipCount: 1_000), 1_000)
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
