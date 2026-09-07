import XCTest
@testable import NeClip

private actor UpdateFetchGate {
    private(set) var calls = 0
    private var continuation: CheckedContinuation<UpdateManifest, Never>?
    private var result: UpdateManifest?
    func fetch() async -> UpdateManifest {
        calls += 1
        if let result { return result }
        return await withCheckedContinuation { continuation = $0 }
    }
    func finish(_ manifest: UpdateManifest) {
        result = manifest
        continuation?.resume(returning: manifest)
        continuation = nil
    }
}

final class UpdateStateTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private func manifest(_ version: String = "1.10.0", build: Int = 17) -> UpdateManifest {
        UpdateManifest(version: version, build: build,
                       release: "https://github.com/AffPapa/neclip/releases/download/v\(version)/NeClip-\(version).dmg",
                       sha256: String(repeating: "a", count: 64))
    }
    private func installed(_ version: String = "1.10.0", build: String = "17", preview: Bool = false) -> InstalledVersion {
        InstalledVersion(info: ["CFBundleShortVersionString": version, "CFBundleVersion": build], isPreview: preview)
    }

    func testInstalledIdentityComesFromProvidedBundleMetadata() {
        XCTAssertEqual(installed().label, "1.10.0 · сборка 17")
        XCTAssertTrue(installed(preview: true).isPreview)
        XCTAssertNil(InstalledVersion(info: [:], isPreview: false).version)
        XCTAssertEqual(InstalledVersion(info: [:], isPreview: false).label, "Не определена")
        XCTAssertNil(installed(build: "invalid").build)
        XCTAssertNil(installed("not-a-version").version)
    }

    @MainActor
    func testCachedResultIsDatedAndComparisonsDoNotFetch() throws {
        let suite = "NeClip.UpdateTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let saved = UpdateSnapshot(manifest: manifest(), checkedAt: date)
        defaults.set(try JSONEncoder().encode(saved), forKey: UpdateChecker.cacheKey)
        for (local, expected) in [(installed("1.9.1"), UpdateChecker.Comparison.available),
                                  (installed(), .equal), (installed("1.11.0"), .localNewer),
                                  (installed(build: "unknown"), .unknown)] {
            let checker = UpdateChecker(installed: local, defaults: defaults, now: { self.date }, fetch: {
                XCTFail("Opening saved version status must not start a network request")
                throw URLError(.cancelled)
            })
            XCTAssertEqual(checker.comparison, expected)
            XCTAssertTrue(checker.isCachedResult)
            XCTAssertEqual(checker.snapshot, saved)
            XCTAssertFalse(checker.isChecking)
            XCTAssertEqual(checker.downloadURL != nil, expected == .available)
        }
    }

    @MainActor
    func testExplicitSuccessPersistsAndFailureRetainsOriginalDate() async throws {
        let suite = "NeClip.UpdateTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let remote = manifest("1.11.0", build: 18)
        let checker = UpdateChecker(installed: installed(), defaults: defaults, now: { self.date }, fetch: { remote })
        XCTAssertNil(checker.snapshot)
        XCTAssertEqual(checker.comparison, .unknown)
        await checker.checkNow()
        XCTAssertEqual(checker.snapshot?.manifest, remote)
        XCTAssertEqual(checker.snapshot?.checkedAt, date)
        XCTAssertFalse(checker.isCachedResult)
        XCTAssertNil(checker.failure)
        let later = date.addingTimeInterval(86_400)
        let offline = UpdateChecker(installed: installed(), defaults: defaults, now: { later }, fetch: {
            throw URLError(.notConnectedToInternet)
        })
        XCTAssertTrue(offline.isCachedResult)
        await offline.checkNow()
        XCTAssertEqual(offline.snapshot?.checkedAt, date)
        XCTAssertEqual(offline.snapshot?.manifest, remote)
        XCTAssertNotNil(offline.failure)
        XCTAssertFalse(offline.isChecking)
        XCTAssertTrue(offline.isCachedResult)
    }

    @MainActor
    func testRepeatedCheckWhileInFlightDoesNotDuplicateRequests() async throws {
        let suite = "NeClip.UpdateTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let gate = UpdateFetchGate()
        let checker = UpdateChecker(installed: installed(), defaults: defaults, fetch: { await gate.fetch() })
        let first = Task { await checker.checkNow() }
        while !checker.isChecking { await Task.yield() }
        await checker.checkNow()
        await gate.finish(manifest())
        await first.value
        let calls = await gate.calls
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(checker.isChecking)
    }

    @MainActor
    func testInvalidCacheAndRemoteAreRejectedWithoutUnsafeDownload() async throws {
        let suite = "NeClip.UpdateTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let bad = UpdateManifest(version: "2.0.0", build: 20, release: "https://example.com/evil.dmg",
                                 sha256: String(repeating: "a", count: 64))
        let invalidCaches = [Data("not JSON".utf8),
                             Data(repeating: 32, count: UpdateManifestPolicy.maximumResponseBytes + 1),
                             try JSONEncoder().encode(UpdateSnapshot(manifest: bad, checkedAt: date)),
                             try JSONEncoder().encode(UpdateSnapshot(manifest: manifest(), checkedAt: date.addingTimeInterval(9999)))]
        for data in invalidCaches {
            defaults.set(data, forKey: UpdateChecker.cacheKey)
            let checker = UpdateChecker(installed: installed(), defaults: defaults, now: { self.date }, fetch: { bad })
            XCTAssertNil(checker.snapshot)
            XCTAssertNil(checker.downloadURL)
            await checker.checkNow()
            XCTAssertNotNil(checker.failure)
            XCTAssertNil(checker.snapshot)
            XCTAssertNil(checker.downloadURL)
        }
    }
}
