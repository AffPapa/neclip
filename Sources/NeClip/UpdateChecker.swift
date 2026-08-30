import AppKit

/// Manual update check against the NeClip landing page.
/// No automatic network requests — runs only when the user picks
/// "Проверить обновления…" from the menu.
@MainActor
enum UpdateChecker {
    private static let versionURL = URL(string: "https://affpapa.org/downloads/neclip-version.json")!
    private static let allowedHost = "affpapa.org"
    private static let maximumResponseBytes = 64 * 1024

    struct RemoteVersion: Decodable {
        let version: String
        let url: String
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static func check() {
        var request = URLRequest(url: versionURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let http = response as? HTTPURLResponse,
                      http.statusCode == 200,
                      http.url?.scheme == "https",
                      http.url?.host == allowedHost,
                      let data,
                      data.count <= maximumResponseBytes,
                      let remote = try? JSONDecoder().decode(RemoteVersion.self, from: data),
                      let downloadURL = safeDownloadURL(remote.url) else {
                    showAlert(title: "Не удалось проверить обновления",
                              text: "Проверьте подключение к интернету и попробуйте ещё раз.")
                    return
                }
                if remote.version.compare(currentVersion, options: .numeric) == .orderedDescending {
                    let alert = NSAlert()
                    alert.messageText = "Доступна версия \(remote.version)"
                    alert.informativeText = "У вас установлена \(currentVersion). Скачать обновление?"
                    alert.addButton(withTitle: "Скачать")
                    alert.addButton(withTitle: "Позже")
                    NSApp.activate(ignoringOtherApps: true)
                    if alert.runModal() == .alertFirstButtonReturn {
                        NSWorkspace.shared.open(downloadURL)
                    }
                } else {
                    showAlert(title: "У вас последняя версия",
                              text: "NeClip \(currentVersion) — новее ничего нет.")
                }
            }
        }.resume()
    }

    private static func safeDownloadURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              url.scheme == "https",
              url.host == allowedHost,
              url.path.hasPrefix("/downloads/") else { return nil }
        return url
    }

    private static func showAlert(title: String, text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
