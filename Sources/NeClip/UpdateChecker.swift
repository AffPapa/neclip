import AppKit

struct UpdateManifest: Decodable, Equatable, Sendable {
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

/// Manual update check against the repository-owned GitHub Pages manifest.
/// No automatic network requests — runs only when the user picks
/// "Проверить обновления…" from the menu.
@MainActor
enum UpdateChecker {
    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var currentBuild: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
    }

    static func check() {
        var request = URLRequest(url: UpdateManifestPolicy.manifestURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let http = response as? HTTPURLResponse,
                      UpdateManifestPolicy.acceptsManifestResponse(http),
                      let data,
                      let validated = UpdateManifestPolicy.validatedManifest(from: data)
                else {
                    showAlert(
                        title: "Не удалось проверить обновления",
                        text: "Проверьте подключение к интернету и попробуйте ещё раз."
                    )
                    return
                }

                let remote = validated.manifest
                if UpdateManifestPolicy.isNewer(
                    remoteVersion: remote.version,
                    remoteBuild: remote.build,
                    currentVersion: currentVersion,
                    currentBuild: currentBuild
                ) {
                    let alert = NSAlert()
                    alert.messageText = "Доступна версия \(remote.version) (\(remote.build))"
                    alert.informativeText = "У вас установлена \(currentVersion) (\(currentBuild)). Скачать обновление с GitHub?"
                    alert.addButton(withTitle: "Скачать")
                    alert.addButton(withTitle: "Позже")
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(validated.downloadURL)
                    }
                } else {
                    showAlert(
                        title: "У вас последняя версия",
                        text: "NeClip \(currentVersion) (\(currentBuild)) — новее ничего нет."
                    )
                }
            }
        }.resume()
    }

    private static func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
