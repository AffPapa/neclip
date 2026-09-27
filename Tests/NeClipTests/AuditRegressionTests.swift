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


}
