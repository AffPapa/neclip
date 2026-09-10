import AppKit

MainActor.assumeIsolated {
#if DEBUG
    if RuntimeIdentity.isScreenshotQA {
        // A Finder/LaunchServices relaunch must retain the fixture's safety
        // boundary even when environment variables and CLI args are absent.
        var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments["capturePausedIndefinitely"] = true
        arguments["automaticLayoutCorrection"] = false
        arguments["rememberLayoutPerApplication"] = false
        UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
    }
#endif
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    // NSApplication.delegate is weak. Keep the owner alive for the entire
    // event loop, including optimized builds with shortened local lifetimes.
    withExtendedLifetime(delegate) { app.run() }
}
