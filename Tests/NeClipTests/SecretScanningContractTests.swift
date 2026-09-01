import Foundation
import XCTest

final class SecretScanningContractTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testSecretScanWorkflowIsReadOnlyPinnedAndRedacted() throws {
        let workflow = try text(".github/workflows/secret-scan.yml")

        XCTAssertTrue(workflow.contains("permissions:\n  contents: read"))
        XCTAssertTrue(workflow.contains("actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"))
        XCTAssertTrue(workflow.contains("fetch-depth: 0"))
        XCTAssertTrue(workflow.contains("persist-credentials: false"))
        XCTAssertTrue(workflow.contains("GITLEAKS_VERSION: 8.30.1"))
        XCTAssertTrue(workflow.contains("shasum -a 256 -c -"))
        XCTAssertTrue(workflow.contains("run: scripts/secret-scan.sh"))
        XCTAssertFalse(workflow.contains("pull_request_target"))
        XCTAssertFalse(workflow.contains("secrets."))
    }

    func testLocalScannerCoversUncommittedFilesAndFullHistory() throws {
        let script = try text("scripts/secret-scan.sh")

        XCTAssertTrue(script.contains("git ls-files -co --exclude-standard -z"))
        XCTAssertTrue(script.contains("[[ -e \"$source_path\" || -L \"$source_path\" ]] || continue"))
        XCTAssertTrue(script.contains("--redact=100"))
        XCTAssertTrue(script.contains("--max-archive-depth=5"))
        XCTAssertTrue(script.contains("--max-decode-depth=8"))
        XCTAssertTrue(script.contains("verify_detector \"GitHub PAT\""))
        XCTAssertTrue(script.contains("verify_detector \"AWS access key\""))
        XCTAssertTrue(script.contains("verify_detector \"Slack bot token\""))
        XCTAssertTrue(script.contains("--full-history HEAD"))
        XCTAssertTrue(script.contains("--all --not HEAD"))
        XCTAssertFalse(script.contains("--no-redact"))
    }

    func testSensitiveLocalArtifactsAreIgnored() throws {
        let gitignore = try text(".gitignore")
        for pattern in [
            ".env.*", "AuthKey_*.p8", "*.pem", "*.p12", "*.key",
            "*.mobileprovision", "*.keychain-db", "*.sqlite", "*.db-wal",
            "*.log", "*.xcarchive", "*.dmg", "*.zip"
        ] {
            XCTAssertTrue(gitignore.contains(pattern), "Missing ignore rule: \(pattern)")
        }
        XCTAssertTrue(gitignore.contains("!.env.example"))
    }

    func testPublicAuditDocumentsDoNotPublishSubmissionIdentifiers() throws {
        let docsURL = repositoryRoot.appendingPathComponent("docs", isDirectory: true)
        let audit = try FileManager.default.contentsOfDirectory(
            at: docsURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix("AUDIT") && $0.pathExtension == "md" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .map { try String(contentsOf: $0, encoding: .utf8) }
        .joined(separator: "\n")
        let regex = try NSRegularExpression(
            pattern: #"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b"#
        )
        let range = NSRange(audit.startIndex..<audit.endIndex, in: audit)
        XCTAssertNil(regex.firstMatch(in: audit, range: range))
    }

    func testSecurityPolicyDescribesReleaseImmutabilityWithoutOverclaiming() throws {
        let policy = try text("SECURITY.md")

        XCTAssertTrue(policy.contains("Releases `v1.3.2` and later"))
        XCTAssertTrue(policy.contains("cannot retroactively lock"))
        XCTAssertFalse(policy.contains("Published releases and their assets are immutable"))
    }

    private func text(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
