import Foundation
import XCTest
@testable import NeClip

final class UpdateManifestTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testPublishedManifestUsesRepositoryOwnedEndpoints() throws {
        let data = try Data(contentsOf: repositoryRoot.appendingPathComponent("docs/version.json"))
        let validated = try XCTUnwrap(UpdateManifestPolicy.validatedManifest(from: data))

        XCTAssertEqual(UpdateManifestPolicy.manifestURL.absoluteString, "https://affpapa.github.io/neclip/version.json")
        XCTAssertEqual(validated.manifest.version, "1.4.0")
        XCTAssertEqual(validated.downloadURL.host, "github.com")
        XCTAssertEqual(
            validated.downloadURL.path,
            "/AffPapa/neclip/releases/download/v1.4.0/NeClip-1.4.0.dmg"
        )
    }

    func testDownloadPolicyRejectsLookalikesAndUnexpectedPaths() {
        XCTAssertNil(UpdateManifestPolicy.safeDownloadURL(
            "https://github.example/AffPapa/neclip/releases/download/v1.3.0/NeClip-1.3.0.dmg",
            version: "1.3.0"
        ))
        XCTAssertNil(UpdateManifestPolicy.safeDownloadURL(
            "https://github.com/Other/neclip/releases/download/v1.3.0/NeClip-1.3.0.dmg",
            version: "1.3.0"
        ))
        XCTAssertNil(UpdateManifestPolicy.safeDownloadURL(
            "https://github.com/AffPapa/neclip/releases/download/v1.3.0/NeClip-1.3.0.dmg?redirect=evil",
            version: "1.3.0"
        ))
        XCTAssertNil(UpdateManifestPolicy.safeDownloadURL(
            "https://user@github.com/AffPapa/neclip/releases/download/v1.3.0/NeClip-1.3.0.dmg",
            version: "1.3.0"
        ))
    }

    func testManifestResponsePolicyRequiresExactGitHubPagesJSON() throws {
        let good = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://affpapa.github.io/neclip/version.json")!,
            statusCode: 200,
            httpVersion: "HTTP/2",
            headerFields: ["Content-Type": "application/json; charset=utf-8"]
        ))
        let wrongHost = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://example.com/neclip/version.json")!,
            statusCode: 200,
            httpVersion: "HTTP/2",
            headerFields: ["Content-Type": "application/json"]
        ))
        let wrongType = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://affpapa.github.io/neclip/version.json")!,
            statusCode: 200,
            httpVersion: "HTTP/2",
            headerFields: ["Content-Type": "text/html"]
        ))

        XCTAssertTrue(UpdateManifestPolicy.acceptsManifestResponse(good))
        XCTAssertFalse(UpdateManifestPolicy.acceptsManifestResponse(wrongHost))
        XCTAssertFalse(UpdateManifestPolicy.acceptsManifestResponse(wrongType))
    }

    func testManifestValidationFailsClosed() {
        let badVersion = manifest(version: "1.3", sha256: String(repeating: "a", count: 64))
        let badHash = manifest(version: "1.3.0", sha256: "not-a-checksum")
        let badURL = manifest(
            version: "1.3.0",
            sha256: String(repeating: "a", count: 64),
            release: "https://example.com/NeClip-1.3.0.dmg"
        )

        XCTAssertNil(UpdateManifestPolicy.validatedManifest(from: Data(badVersion.utf8)))
        XCTAssertNil(UpdateManifestPolicy.validatedManifest(from: Data(badHash.utf8)))
        XCTAssertNil(UpdateManifestPolicy.validatedManifest(from: Data(badURL.utf8)))
        XCTAssertNil(UpdateManifestPolicy.validatedManifest(from: Data(repeating: 0, count: UpdateManifestPolicy.maximumResponseBytes + 1)))
    }

    private func manifest(
        version: String,
        sha256: String,
        release: String? = nil
    ) -> String {
        let release = release ?? "https://github.com/AffPapa/neclip/releases/download/v\(version)/NeClip-\(version).dmg"
        return """
        {
          "version": "\(version)",
          "build": 5,
          "release": "\(release)",
          "sha256": "\(sha256)"
        }
        """
    }
}
