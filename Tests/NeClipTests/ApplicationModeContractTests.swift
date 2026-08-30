import Foundation
import XCTest

final class ApplicationModeContractTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testReleaseContractKeepsNeClipInMenuBarAndOutOfDock() throws {
        let infoData = try Data(contentsOf: repositoryRoot.appendingPathComponent("Resources/Info.plist"))
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)

        let main = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/main.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(main.contains("setActivationPolicy(.accessory)"))

        let statusBar = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/StatusBarController.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(statusBar.contains("NSStatusBar.system.statusItem"))
        XCTAssertTrue(statusBar.contains("statusItem.isVisible = true"))
    }

    func testPackageUsesSwift6AndNoHotKeyDependency() throws {
        let package = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(package.contains("swift-tools-version: 6.2"))
        XCTAssertTrue(package.contains("exact: \"7.10.0\""))
        XCTAssertFalse(package.contains("soffes/HotKey"))
        XCTAssertFalse(package.contains("import HotKey"))
    }

    func testReleaseScriptFailsClosedAndAvoidsDeepSigning() throws {
        let script = try String(
            contentsOf: repositoryRoot.appendingPathComponent("build-app.sh"),
            encoding: .utf8
        )

        let credentialPreflight = try XCTUnwrap(
            script.range(of: "notarytool history --keychain-profile")
        )
        let temporaryWorkspace = try XCTUnwrap(script.range(of: "WORK_DIR=$(mktemp -d"))
        let distMutation = try XCTUnwrap(script.range(of: "rm -rf dist/NeClip.app"))

        XCTAssertLessThan(credentialPreflight.lowerBound, temporaryWorkspace.lowerBound)
        XCTAssertLessThan(credentialPreflight.lowerBound, distMutation.lowerBound)
        XCTAssertTrue(script.contains("notarytool submit \"$ZIP\""))
        XCTAssertTrue(script.contains("stapler staple \"$APP\""))
        XCTAssertTrue(script.contains("stapler staple \"$DMG\""))
        XCTAssertTrue(script.contains("spctl --assess --type execute"))
        XCTAssertFalse(script.contains("codesign --deep"))
        XCTAssertTrue(script.contains("diskutil image create from"))
        XCTAssertTrue(script.contains("diskutil image attach --readOnly"))
        XCTAssertFalse(script.contains("hdiutil"))
        XCTAssertTrue(script.contains("(cd \"$WORK_DIR\" && shasum -a 256"))
    }

    func testGitHubIsTheOnlyPublicationAndUpdateSource() throws {
        let fileManager = FileManager.default
        XCTAssertFalse(fileManager.fileExists(atPath: repositoryRoot.appendingPathComponent("landing").path))

        let updater = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/UpdateChecker.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(updater.contains("https://affpapa.github.io/neclip/version.json"))
        XCTAssertTrue(updater.contains("/AffPapa/neclip/releases/download"))
        XCTAssertFalse(updater.contains("https://affpapa.org"))

        let website = try String(
            contentsOf: repositoryRoot.appendingPathComponent("docs/index.html"),
            encoding: .utf8
        )
        XCTAssertFalse(website.contains("https://affpapa.org"))
        XCTAssertTrue(website.contains("project.json"))
    }
}
