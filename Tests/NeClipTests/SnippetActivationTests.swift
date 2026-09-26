import AppKit
import XCTest
@testable import NeClip

final class SnippetActivationTests: XCTestCase {
    func testExcludedClipboardProvenanceSurvivesTimerConsumption() {
        var guardState = ClipboardExcludedChangeGuard(capacity: 2)
        guardState.record(changeCount: 42)
        XCTAssertTrue(guardState.consumeIfExcluded(changeCount: 42))
        XCTAssertFalse(guardState.consumeIfExcluded(changeCount: 42))
        XCTAssertTrue(guardState.isExcluded(changeCount: 42))
        XCTAssertTrue(guardState.isExcluded(changeCount: 42))
        guardState.record(changeCount: 43)
        guardState.record(changeCount: 44)
        XCTAssertFalse(guardState.isExcluded(changeCount: 42))
        XCTAssertTrue(guardState.isExcluded(changeCount: 44))
    }

    @MainActor
    func testRepeatedProtectedClipboardExpansionNeverEntersHistory() async throws {
        try await withCaptureSettings {
            let board = NSPasteboard(name: .init("neclip-protected-repeat-\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            board.clearContents()
            XCTAssertTrue(board.setString("SYNTHETIC fixture", forType: .string))
            XCTAssertTrue(board.setData(Data(), forType: .init("org.nspasteboard.ConcealedType")))
            let storage = try Storage(inMemory: true, installStarterContent: false)
            let monitor = ClipboardMonitor(pasteboard: board, storage: storage)
            monitor.start()
            defer { monitor.stop() }
            for _ in 0..<3 {
                let context = SnippetClipboardContext(generation: board.changeCount,
                    isProtected: !Set(board.types ?? []).isDisjoint(with: ClipboardMonitor.concealedTypes))
                XCTAssertTrue(context.isProtected)
                let text = try SnippetRenderer.render("{clipboard}", clipboard: board.string(forType: .string))
                let done = expectation(description: "protected copy")
                PasteService.paste(snippet: Snippet(title: "Fixture", content: text), targetPID: nil,
                    copyOnly: true, pasteboard: board, protectedContent: context.isProtected, onCopied: { value in
                        XCTAssertFalse(monitor.recordSnippet(value, sourceBundleID: "org.neclip.fixture", clipboardContext: context))
                    }) { result in
                        XCTAssertEqual(result, .copiedOnly)
                        done.fulfill()
                    }
                await fulfillment(of: [done], timeout: 2)
            }
            await monitor.stopAndDrainAsync()
            XCTAssertEqual(storage.count, 0)
        }
    }

    @MainActor
    func testExcludedProvenanceSurvivesRestartAndCoversLateTransitionCopy() async throws {
        try await withCaptureSettings {
            let board = NSPasteboard(name: .init("neclip-provenance-\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            board.clearContents()
            XCTAssertTrue(board.setString("synthetic excluded", forType: .string))
            let storage = try Storage(inMemory: true, installStarterContent: false)
            let monitor = ClipboardMonitor(pasteboard: board, storage: storage)
            var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
            arguments["excludedApps"] = ["org.neclip.excluded"]
            UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            monitor.start()
            defer { monitor.stop() }
            monitor.applicationDidActivate(bundleID: "org.neclip.excluded")
            monitor.applicationDidActivate(bundleID: "org.neclip.allowed")
            let excludedGeneration = board.changeCount
            let afterTransition = Date().addingTimeInterval(10)
            XCTAssertTrue(monitor.isClipboardGenerationExcluded(excludedGeneration, now: afterTransition))
            monitor.stopAndDrain()
            monitor.start()
            XCTAssertTrue(monitor.isClipboardGenerationExcluded(excludedGeneration, now: afterTransition))
            board.clearContents()
            XCTAssertTrue(board.setString("synthetic late excluded copy", forType: .string))
            let context = SnippetClipboardContext(generation: board.changeCount,
                isProtected: monitor.isClipboardGenerationExcluded(board.changeCount))
            XCTAssertTrue(context.isProtected, "Late copy in transition must remain protected on expansion")
            let done = expectation(description: "late protected copy")
            PasteService.paste(snippet: Snippet(title: "Fixture", content: "synthetic late excluded copy"),
                targetPID: nil, copyOnly: true, pasteboard: board, protectedContent: context.isProtected) { _ in done.fulfill() }
            await fulfillment(of: [done], timeout: 2)
            XCTAssertFalse(Set(board.types ?? []).isDisjoint(with: ClipboardMonitor.concealedTypes))
            await monitor.stopAndDrainAsync()
            XCTAssertEqual(storage.count, 0)
        }
    }

    @MainActor
    private final class Target: NSObject {
        var ids: [Int64] = []
        @objc func pasteClipOriginal(_ sender: NSMenuItem) {
            ids.append((sender.representedObject as? NSNumber)?.int64Value ?? -1)
        }
    }

    @MainActor
    private func event(_ key: String = "\r", modifiers: NSEvent.ModifierFlags = [], code: UInt16 = 36) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                                      timestamp: 0, windowNumber: 0, context: nil, characters: key,
                                      charactersIgnoringModifiers: key, isARepeat: false, keyCode: code))
    }

    @MainActor
    func testReturnNeverBecomesAGlobalHistoryShortcut() throws {
        _ = NSApplication.shared
        let target = Target(), root = NSMenu(title: "History")
        root.autoenablesItems = false
        for id: Int64 in [1, 2, 3] {
            let folder = NSMenuItem(title: "History \(id)", action: nil, keyEquivalent: "")
            let submenu = NSMenu(title: "Actions")
            submenu.autoenablesItems = false
            submenu.addItem(StatusBarController.makeOriginalPasteItem(clipID: id, target: target))
            folder.submenu = submenu
            root.addItem(folder)
        }
        let snippetFolder = NSMenu(title: "Snippets")
        snippetFolder.autoenablesItems = false
        let selected = StatusBarController.makeOriginalPasteItem(clipID: 100, target: target)
        selected.title = "Selected snippet"
        snippetFolder.addItem(selected)
        let parent = NSMenuItem(title: "Snippets", action: nil, keyEquivalent: "")
        parent.submenu = snippetFolder
        root.addItem(parent)

        for flags: NSEvent.ModifierFlags in [[], .shift, .command, .control] {
            XCTAssertFalse(root.performKeyEquivalent(with: try event(modifiers: flags)))
        }
        XCTAssertFalse(root.performKeyEquivalent(with: try event("\u{3}", code: 76)))
        XCTAssertTrue(target.ids.isEmpty, "Return must not select the first closed history submenu")
        snippetFolder.performActionForItem(at: 0)
        XCTAssertEqual(target.ids, [100])
        // A regular Cmd-digit shortcut remains supported independently of Return.
        let first = try XCTUnwrap(root.items.first?.submenu?.items.first)
        first.keyEquivalent = "1"
        first.keyEquivalentModifierMask = [.command]
        XCTAssertTrue(root.performKeyEquivalent(with: try event("1", modifiers: .command, code: 18)))
        XCTAssertEqual(target.ids, [100, 1])
    }

    @MainActor
    func testLegacyReturnEquivalentReproducesUnselectedHistoryActivation() throws {
        _ = NSApplication.shared
        let target = Target(), root = NSMenu(), child = NSMenu()
        root.autoenablesItems = false
        child.autoenablesItems = false
        let entry = StatusBarController.makeOriginalPasteItem(clipID: 1, target: target)
        entry.keyEquivalent = "\r" // The pre-2.8.4 regression.
        child.addItem(entry)
        let parent = NSMenuItem(title: "Unselected history", action: nil, keyEquivalent: "")
        parent.submenu = child
        root.addItem(parent)
        XCTAssertTrue(root.performKeyEquivalent(with: try event()))
        XCTAssertEqual(target.ids, [1])
    }

    func testExplicitSnippetCaptureRespectsEveryPrivacyGate() {
        func reason(ignored: Bool = false, paused: Bool = false, allowed: Bool = true,
                    source: String? = "org.neclip.fixture", excluded: Set<String> = [], transition: Bool = false) -> ClipboardCaptureSkipReason? {
            SnippetHistoryPolicy.rejectionReason(ignored: ignored, paused: paused, clipboardAllowed: allowed,
                sourceBundleID: source, excludedApps: excluded, excludedTransition: transition)
        }
        XCTAssertNil(reason())
        XCTAssertEqual(reason(ignored: true), .ignoredOnce)
        XCTAssertEqual(reason(paused: true), .paused)
        XCTAssertEqual(reason(allowed: false), .pasteboardAccessDenied)
        XCTAssertEqual(reason(source: nil), .excludedOrUnknownSource)
        XCTAssertEqual(reason(excluded: ["ORG.NECLIP.FIXTURE"]), .excludedOrUnknownSource)
        XCTAssertEqual(reason(transition: true), .excludedOrUnknownSource)
        for app in SensitiveApplicationPolicy.bundleIDs {
            XCTAssertEqual(reason(source: app), .excludedOrUnknownSource)
        }
    }

    func testQuickShortcutDoesNotStealCommandReturnOrCommandClick() {
        for shortcut in (1...9).map(String.init) {
            for flags: NSEvent.ModifierFlags in [.command, [.command, .shift], [.command, .control]] {
                XCTAssertEqual(MenuActivationPolicy.modifiers(keyEquivalent: shortcut, characters: shortcut,
                    isKeyDown: true, modifiers: flags), flags.subtracting(.command))
                for other in ["\r", "\u{3}", "x"] {
                    XCTAssertEqual(MenuActivationPolicy.modifiers(keyEquivalent: shortcut, characters: other,
                        isKeyDown: true, modifiers: flags), flags)
                }
                XCTAssertEqual(MenuActivationPolicy.modifiers(keyEquivalent: shortcut, characters: nil,
                    isKeyDown: false, modifiers: flags), flags)
            }
        }
        XCTAssertEqual(MenuActivationPolicy.modifiers(keyEquivalent: "", characters: "\r", isKeyDown: true,
                                                     modifiers: .shift), .shift)
    }

    func testClipboardDependencyUsesRenderersEscapingRules() throws {
        for (template, usesClipboard) in [
            ("plain text", false), ("{{clipboard}}", false), ("{clipboard}", true),
            ("{{{clipboard}}}", false), ("{{clipboard}}{clipboard}", true),
            ("{date} {time:iso}", false), ("{clipboard}\u{301}", true), ("", false)
        ] {
            XCTAssertEqual(SnippetRenderer.usesClipboard(template), usesClipboard, template)
            let first = try SnippetRenderer.render(template, clipboard: "FIRST")
            let second = try SnippetRenderer.render(template, clipboard: "SECOND")
            XCTAssertEqual(first != second, usesClipboard, template)
        }
    }

    @MainActor
    private func withCaptureSettings<T>(_ body: () async throws -> T) async rethrows -> T {
        let defaults = UserDefaults.standard
        let previous = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        defer { defaults.setVolatileDomain(previous, forName: UserDefaults.argumentDomain) }
        var arguments = previous
        arguments["capturePausedIndefinitely"] = false
        arguments["capturePausedUntil"] = Date.distantPast
        arguments["ignoreNextCopy"] = false
        arguments["appendNextCopy"] = false
        arguments["excludedApps"] = [String]()
        arguments["sensitiveContentRules"] = [String]()
        arguments["maximumTextCaptureKilobytes"] = 64
        defaults.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
        return try await body()
    }

    @MainActor
    func testCopiedRenderedSnippetBecomesNewestDeduplicatedHistoryWithoutLibraryReorder() async throws {
        try await withCaptureSettings {
            let board = NSPasteboard(name: .init("neclip-snippet-test-\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            board.clearContents()
            XCTAssertTrue(board.setString("synthetic previous", forType: .string))
            let storage = try Storage(inMemory: true, installStarterContent: false)
            let monitor = ClipboardMonitor(pasteboard: board, storage: storage)
            monitor.start()
            defer { monitor.stop() }
            let rendered = try SnippetRenderer.render("Привет 👋\n{clipboard}", clipboard: "fixture")
            let originalID = try storage.insert(ClipItem(kind: .text, title: "old snippet", text: rendered,
                                                        rtf: Data([1]), createdAt: Date(timeIntervalSince1970: 1)))
            try storage.insert(ClipItem(kind: .text, title: "newer history", text: "other", createdAt: Date(timeIntervalSince1970: 2)))
            let folder = try XCTUnwrap(storage.addFolder(title: "Fixture folder"))
            try storage.addSnippet(folderID: folder.id, title: "First", content: "stable first")
            let template = try XCTUnwrap(storage.addSnippet(folderID: folder.id, title: "Template", content: "Привет 👋\n{clipboard}"))
            let before = try storage.menuSnippetSnapshot().snippets
            XCTAssertEqual(before.count, 2)
            let done = expectation(description: "copied")
            var calls = 0
            PasteService.paste(snippet: Snippet(title: "Template", content: rendered), targetPID: nil,
                               copyOnly: true, pasteboard: board, onCopied: { text in
                calls += 1
                XCTAssertEqual(text, rendered)
                XCTAssertTrue(monitor.recordSnippet(text, sourceBundleID: "org.neclip.fixture"))
            }) { result in
                XCTAssertEqual(result, .copiedOnly)
                done.fulfill()
            }
            await fulfillment(of: [done], timeout: 2)
            await monitor.stopAndDrainAsync()
            XCTAssertEqual(calls, 1)
            XCTAssertEqual(board.string(forType: .string), rendered)
            let rows = try storage.allClipSummaries()
            XCTAssertEqual(rows.count, 2)
            XCTAssertEqual(rows.first?.id, originalID)
            let newest = try XCTUnwrap(storage.fetchClip(id: XCTUnwrap(originalID)))
            XCTAssertEqual(newest.text, rendered)
            XCTAssertNil(newest.rtf)
            XCTAssertEqual(try storage.menuSnippetSnapshot().snippets.map(\.id), before.map(\.id))
            XCTAssertEqual(try storage.fetchSnippet(id: XCTUnwrap(template.id))?.content, "Привет 👋\n{clipboard}")
            XCTAssertTrue(ClipboardWriteGuard.shared.consumeIfOwn(changeCount: board.changeCount))
        }
    }

    @MainActor
    func testStoppedCaptureAndQueuedPauseDoNotLeakSnippetAfterCleanup() async throws {
        try await withCaptureSettings {
            let board = NSPasteboard(name: .init("neclip-snippet-pause-\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            let storage = try Storage(inMemory: true, installStarterContent: false)
            let queue = DispatchQueue(label: "neclip.snippet.pause.test")
            let monitor = ClipboardMonitor(pasteboard: board, storage: storage, processingQueue: queue)
            XCTAssertFalse(monitor.recordSnippet("not running", sourceBundleID: "org.neclip.fixture"))
            monitor.start()
            defer { monitor.stop() }
            let release = DispatchSemaphore(value: 0)
            queue.async { release.wait() }
            XCTAssertTrue(monitor.recordSnippet("queued fixture", sourceBundleID: "org.neclip.fixture"))
            var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
            arguments["capturePausedIndefinitely"] = true
            UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            release.signal()
            await monitor.stopAndDrainAsync()
            XCTAssertEqual(storage.count, 0)
            XCTAssertFalse(monitor.recordSnippet("after stop", sourceBundleID: "org.neclip.fixture"))
        }
    }

    @MainActor
    func testDisablingImageHistoryRejectsAlreadyQueuedScreenshot() async throws {
        try await withCaptureSettings {
            let board = NSPasteboard(name: .init("neclip-screenshot-setting-\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            let storage = try Storage(inMemory: true, installStarterContent: false)
            let queue = DispatchQueue(label: "neclip.screenshot.setting.test")
            let monitor = ClipboardMonitor(pasteboard: board, storage: storage, processingQueue: queue)
            var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
            arguments["captureImages"] = true
            UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            monitor.start()
            defer { monitor.stop() }
            let context = try ScreenshotRenderer.context(width: 2, height: 2)
            let png = try ScreenshotRenderer.encode(try XCTUnwrap(context.makeImage()), annotations: [], format: .png)
            let release = DispatchSemaphore(value: 0)
            queue.async { release.wait() }
            XCTAssertTrue(monitor.recordScreenshot(png, width: 2, height: 2, sourceBundleID: "org.neclip.fixture"))
            arguments["captureImages"] = false
            UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            release.signal()
            await monitor.stopAndDrainAsync()
            XCTAssertEqual(storage.count, 0)
        }
    }

    @MainActor
    func testExplicitSnippetUsesNormalSensitiveEmptyAndSizeLimits() async throws {
        try await withCaptureSettings {
            let board = NSPasteboard(name: .init("neclip-snippet-limits-\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            let storage = try Storage(inMemory: true, installStarterContent: false)
            let monitor = ClipboardMonitor(pasteboard: board, storage: storage)
            var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
            arguments["sensitiveContentRules"] = ["SYNTHETIC_PRIVATE"]
            UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            monitor.start()
            defer { monitor.stop() }
            XCTAssertFalse(monitor.recordSnippet("protected fixture", sourceBundleID: "org.neclip.fixture",
                clipboardContext: SnippetClipboardContext(generation: board.changeCount, isProtected: true)))
            for text in ["  \n\t", "SYNTHETIC_PRIVATE fixture", String(repeating: "я", count: 40_000)] {
                XCTAssertTrue(monitor.recordSnippet(text, sourceBundleID: "org.neclip.fixture"))
            }
            await monitor.stopAndDrainAsync()
            XCTAssertEqual(storage.count, 0)
        }
    }

    @MainActor
    func testNewExclusionRejectsAlreadyQueuedSnippetBeforeStorage() async throws {
        try await withCaptureSettings {
            let board = NSPasteboard(name: .init("neclip-exclusion-\(UUID().uuidString)"))
            defer { board.releaseGlobally() }
            let storage = try Storage(inMemory: true, installStarterContent: false)
            let queue = DispatchQueue(label: "neclip.exclusion.test")
            let monitor = ClipboardMonitor(pasteboard: board, storage: storage, processingQueue: queue)
            monitor.start()
            defer { monitor.stop() }
            let release = DispatchSemaphore(value: 0)
            queue.async { release.wait() }
            XCTAssertTrue(monitor.recordSnippet("queued fixture", sourceBundleID: "org.neclip.fixture"))
            var arguments = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
            arguments["excludedApps"] = ["org.neclip.fixture"]
            UserDefaults.standard.setVolatileDomain(arguments, forName: UserDefaults.argumentDomain)
            release.signal()
            await monitor.stopAndDrainAsync()
            XCTAssertEqual(storage.count, 0)
        }
    }
}
