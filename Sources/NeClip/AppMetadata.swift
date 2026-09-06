import AppKit

struct AppMetadata {
    let name: String
    let icon: NSImage
}

@MainActor
final class AppMetadataStore {
    static let shared = AppMetadataStore()

    private final class Box: NSObject {
        let value: AppMetadata

        init(_ value: AppMetadata) {
            self.value = value
        }
    }

    private let cache = NSCache<NSString, Box>()

    private init() { cache.countLimit = 200 }

    func metadata(for bundleIdentifier: String?) -> AppMetadata {
        guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
            return fallback
        }

        if let cached = cache.object(forKey: bundleIdentifier as NSString) {
            return cached.value
        }

        let workspace = NSWorkspace.shared
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            let value = AppMetadata(name: readableFallbackName(bundleIdentifier), icon: fallback.icon)
            cache.setObject(Box(value), forKey: bundleIdentifier as NSString)
            return value
        }

        let bundle = Bundle(url: url)
        let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let icon = workspace.icon(forFile: url.path)
        icon.size = NSSize(width: 24, height: 24)
        let value = AppMetadata(name: name, icon: icon)
        cache.setObject(Box(value), forKey: bundleIdentifier as NSString)
        return value
    }

    private lazy var fallback: AppMetadata = {
        let icon = NSImage(systemSymbolName: "app", accessibilityDescription: "Неизвестное приложение")
            ?? NSImage(size: NSSize(width: 24, height: 24))
        icon.size = NSSize(width: 24, height: 24)
        return AppMetadata(name: "Неизвестное приложение", icon: icon)
    }()

    private func readableFallbackName(_ bundleIdentifier: String) -> String {
        guard let last = bundleIdentifier.split(separator: ".").last, !last.isEmpty else {
            return fallback.name
        }
        return String(last).replacingOccurrences(of: "-", with: " ").capitalized
    }
}
