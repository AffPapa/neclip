import AppKit

MainActor.assumeIsolated {
#if DEBUG
    if RuntimeIdentity.isIsolatedPreview {
        // Preview windows never record the user's real clipboard, including
        // when Finder relaunches the bundle without its original arguments.
        var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        arguments["capturePausedIndefinitely"] = true
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
