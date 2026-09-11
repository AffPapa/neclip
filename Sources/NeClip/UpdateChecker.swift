import AppKit
import Combine

struct UpdateManifest: Codable, Equatable, Sendable {
    let version: String
    let build: Int
    let release: String
    let sha256: String
}

enum UpdateManifestPolicy {
    static let manifestURL = URL(string: "https://affpapa.github.io/neclip/version.json")!
    static let maximumResponseBytes = 64 * 1024

    private static let manifestHost = "affpapa.github.io"
    private static let manifestPath = "/neclip/version.json"
    private static let releaseHost = "github.com"
    private static let releaseRepositoryPath = "/AffPapa/neclip/releases/download"

    static func acceptsManifestResponse(_ response: HTTPURLResponse) -> Bool {
        guard response.statusCode == 200,
              let url = response.url,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == manifestHost,
              url.path == manifestPath,
              url.user == nil,
              url.password == nil,
              url.port == nil,
              url.query == nil,
              url.fragment == nil else { return false }

        return response.mimeType == "application/json"
            || response.mimeType == "text/json"
    }

    static func validatedManifest(from data: Data) -> (manifest: UpdateManifest, downloadURL: URL)? {
        guard !data.isEmpty,
              data.count <= maximumResponseBytes,
              let manifest = try? JSONDecoder().decode(UpdateManifest.self, from: data),
              isValidVersion(manifest.version),
              manifest.build > 0,
              isValidSHA256(manifest.sha256),
              let downloadURL = safeDownloadURL(manifest.release, version: manifest.version)
        else { return nil }

        return (manifest, downloadURL)
    }

    static func safeDownloadURL(_ value: String, version: String) -> URL? {
        guard isValidVersion(version),
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == releaseHost,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil,
              components.path == "\(releaseRepositoryPath)/v\(version)/NeClip-\(version).dmg"
        else { return nil }

        return components.url
    }

    static func isValidVersion(_ value: String) -> Bool {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 3 else { return false }
        return components.allSatisfy { component in
            !component.isEmpty && component.allSatisfy(\.isNumber) && Int(component) != nil
        }
    }

    static func isValidSHA256(_ value: String) -> Bool {
        value.count == 64 && value.unicodeScalars.allSatisfy { scalar in
            (48...57).contains(scalar.value) || (65...70).contains(scalar.value) || (97...102).contains(scalar.value)
        }
    }

    static func isNewer(
        remoteVersion: String,
        remoteBuild: Int,
        currentVersion: String,
        currentBuild: Int
    ) -> Bool {
        switch remoteVersion.compare(currentVersion, options: .numeric) {
        case .orderedDescending:
            return true
        case .orderedSame:
            return remoteBuild > currentBuild
        case .orderedAscending:
            return false
        }
    }
}

enum UpdateCheckError: Error, Equatable {
    case invalidResponse, oversizedResponse
}

/// No redirect is needed for the exact repository-owned manifest. Refusing it
/// here prevents sending even a follow-up request to an untrusted destination.
final class UpdateRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

enum UpdateTransport {
    static func configuration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        configuration.timeoutIntervalForResource = 15
        return configuration
    }

    static func fetch(configuration: URLSessionConfiguration = configuration()) async throws -> UpdateManifest {
        var request = URLRequest(url: UpdateManifestPolicy.manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let session = URLSession(configuration: configuration)
        // Cancels the body stream as well, including malformed/oversized replies.
        defer { session.invalidateAndCancel() }
        let (bytes, response) = try await session.bytes(for: request, delegate: UpdateRedirectPolicy())
        guard let http = response as? HTTPURLResponse,
              UpdateManifestPolicy.acceptsManifestResponse(http) else { throw UpdateCheckError.invalidResponse }
        guard response.expectedContentLength <= UpdateManifestPolicy.maximumResponseBytes else {
            throw UpdateCheckError.oversizedResponse
        }
        var data = Data()
        for try await byte in bytes {
            guard data.count < UpdateManifestPolicy.maximumResponseBytes else {
                throw UpdateCheckError.oversizedResponse
            }
            data.append(byte)
        }
        guard let validated = UpdateManifestPolicy.validatedManifest(from: data) else {
            throw UpdateCheckError.invalidResponse
        }
        return validated.manifest
    }
}

struct InstalledVersion: Equatable {
    let version: String?
    let build: Int?
    let isPreview: Bool

    init(info: [String: Any] = Bundle.main.infoDictionary ?? [:], isPreview: Bool = RuntimeIdentity.isIsolatedPreview) {
        let version = info["CFBundleShortVersionString"] as? String
        self.version = version.flatMap { UpdateManifestPolicy.isValidVersion($0) ? $0 : nil }
        let build = (info["CFBundleVersion"] as? String).flatMap(Int.init)
        self.build = build.flatMap { $0 > 0 ? $0 : nil }
        self.isPreview = isPreview
    }

    var label: String {
        guard let version else { return "Не определена" }
        return build.map { "\(version) · сборка \($0)" } ?? "\(version) · сборка не определена"
    }
}

struct UpdateSnapshot: Codable, Equatable {
    let manifest: UpdateManifest
    let checkedAt: Date
}

/// Explicit checks only. Initialization and viewing stored status never use the
/// network; a saved result always keeps its original successful-check date.
@MainActor
final class UpdateChecker: ObservableObject {
    enum Comparison: Equatable { case unknown, available, equal, localNewer }
    static let shared = UpdateChecker()
    // The cache schema is intentionally versioned.  A previous build could
    // leave an old release (for example 2.4.0) in UserDefaults; showing that
    // value as the current "latest" version is worse than showing no result.
    // Bumping the key makes every release start with an unambiguous state and
    // avoids presenting stale metadata from an older updater implementation.
    static let cacheKey = "NeClip.lastVerifiedUpdate.v2"
    let installed: InstalledVersion
    @Published private(set) var snapshot: UpdateSnapshot?
    @Published private(set) var isChecking = false
    @Published private(set) var isCachedResult = false
    @Published private(set) var failure: String?
    private let defaults: UserDefaults
    private let now: () -> Date
    private let fetch: @Sendable () async throws -> UpdateManifest

    init(installed: InstalledVersion = InstalledVersion(), defaults: UserDefaults = .standard,
         now: @escaping () -> Date = Date.init,
         fetch: @escaping @Sendable () async throws -> UpdateManifest = { try await UpdateTransport.fetch() }) {
        self.installed = installed
        self.defaults = defaults
        self.now = now
        self.fetch = fetch
        if let data = defaults.data(forKey: Self.cacheKey), data.count <= UpdateManifestPolicy.maximumResponseBytes,
           let saved = try? JSONDecoder().decode(UpdateSnapshot.self, from: data),
           saved.checkedAt.timeIntervalSince1970.isFinite,
           saved.checkedAt.timeIntervalSince1970 >= 0,
           saved.checkedAt <= now().addingTimeInterval(300),
           let manifestData = try? JSONEncoder().encode(saved.manifest),
           UpdateManifestPolicy.validatedManifest(from: manifestData) != nil {
            snapshot = saved
            isCachedResult = true
        }
    }

    var comparison: Comparison {
        guard let remote = snapshot?.manifest, let version = installed.version, let build = installed.build else {
            return .unknown
        }
        if UpdateManifestPolicy.isNewer(remoteVersion: remote.version, remoteBuild: remote.build,
                                        currentVersion: version, currentBuild: build) { return .available }
        if UpdateManifestPolicy.isNewer(remoteVersion: version, remoteBuild: build,
                                        currentVersion: remote.version, currentBuild: remote.build) { return .localNewer }
        return .equal
    }

    var status: String {
        if isChecking { return "Проверяем GitHub…" }
        if let failure { return failure }
        switch comparison {
        case .unknown: return snapshot == nil ? "Версия на GitHub ещё не проверялась" : "Не удалось определить версию этой копии"
        case .available: return "По последней проверке доступно обновление"
        case .equal: return "На момент проверки версии совпадали"
        case .localNewer: return "Эта сборка новее опубликованной на момент проверки"
        }
    }

    var downloadURL: URL? {
        guard comparison == .available, let remote = snapshot?.manifest else { return nil }
        return UpdateManifestPolicy.safeDownloadURL(remote.release, version: remote.version)
    }

    func check() { Task { await checkNow() } }

    func checkNow() async {
        guard !isChecking else { return }
        isChecking = true
        failure = nil
        defer { isChecking = false }
        do {
            let manifest = try await fetch()
            guard let data = try? JSONEncoder().encode(manifest),
                  UpdateManifestPolicy.validatedManifest(from: data) != nil else { throw UpdateCheckError.invalidResponse }
            let snapshot = UpdateSnapshot(manifest: manifest, checkedAt: now())
            self.snapshot = snapshot
            isCachedResult = false
            if let data = try? JSONEncoder().encode(snapshot) { defaults.set(data, forKey: Self.cacheKey) }
        } catch {
            isCachedResult = snapshot != nil
            failure = error is UpdateCheckError
                ? "GitHub вернул неподходящий ответ. Повторите проверку позже."
                : "Сейчас проверить не удалось. Проверьте интернет и повторите попытку."
        }
    }
}
