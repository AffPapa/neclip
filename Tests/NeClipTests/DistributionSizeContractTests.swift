import Foundation
import XCTest

final class DistributionSizeContractTests: XCTestCase {
    func testDebugSymbolsAreArchivedBeforeStrippingAndSigning() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let script = try String(contentsOf: root.appendingPathComponent("build-app.sh"), encoding: .utf8)
        let symbols = try XCTUnwrap(script.range(of: "xcrun dsymutil"))
        let strip = try XCTUnwrap(script.range(of: "xcrun strip -S -x"))
        let sign = try XCTUnwrap(script.range(of: "codesign --force --options runtime"))
        XCTAssertLessThan(symbols.lowerBound, strip.lowerBound)
        XCTAssertLessThan(strip.lowerBound, sign.lowerBound)
        XCTAssertTrue(script.contains("\"$APP_UUID\" == \"$DSYM_UUID\""))
        XCTAssertTrue(script.contains("cp -R \"$WORK_DIR/NeClip.dSYM\" \"$DIST_STAGE/NeClip.dSYM\""))
        XCTAssertTrue(script.contains("xcrun stapler validate \"$APP\""))
    }
}
