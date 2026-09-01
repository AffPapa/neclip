import Foundation
import XCTest

final class ApplicationModeContractTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testReleaseContractKeepsNeClipInMenuBarAndOutOfDock() throws {
        let infoData = try Data(contentsOf: repositoryRoot.appendingPathComponent("Resources/Info.plist"))
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: infoData, format: nil) as? [String: Any]
        )
        XCTAssertEqual(plist["LSUIElement"] as? Bool, true)
        XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, "1.5.0")
        XCTAssertEqual(plist["CFBundleVersion"] as? String, "9")

        let main = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/main.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(main.contains("setActivationPolicy(.accessory)"))

        let statusBar = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/StatusBarController.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(statusBar.contains("NSStatusBar.system.statusItem"))
        XCTAssertTrue(statusBar.contains("statusItem.isVisible = true"))
        XCTAssertTrue(statusBar.contains("Действия с верхним элементом"))
        XCTAssertTrue(statusBar.contains("#selector(toggleFirstResultPin)"))
        XCTAssertTrue(statusBar.contains("#selector(saveFirstResultAsSnippet)"))
        XCTAssertTrue(statusBar.contains("#selector(deleteFirstResult)"))
        XCTAssertTrue(statusBar.contains("#selector(undoLastDeletion)"))
        XCTAssertEqual(statusBar.components(separatedBy: "#selector(quitApplication)").count - 1, 2)
        XCTAssertFalse(statusBar.contains("#selector(NSApplication.terminate"))
        XCTAssertTrue(statusBar.contains("NSApp.terminate(nil)"))
        XCTAssertTrue(statusBar.contains("MenuAppearance.applyEffectiveAppearance"))
        XCTAssertTrue(statusBar.contains("MenuTitleFormatter.format"))
        XCTAssertTrue(statusBar.contains("Вставить и удалить"))
        XCTAssertTrue(statusBar.contains("За последний час…"))
        XCTAssertTrue(statusBar.contains("Запоминать раскладку приложений"))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: repositoryRoot
                    .appendingPathComponent("Sources/NeClip/ClipboardPanelController.swift").path
            )
        )
    }

    func testUnifiedMenuHotkeyAndSnippetEditorContractsArePresent() throws {
        let settings = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/Settings.swift"),
            encoding: .utf8
        )
        let coordinator = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/HotKeyCoordinator.swift"),
            encoding: .utf8
        )
        let editor = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/SnippetsEditor.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(settings.contains("MenuTitleFormatter.normalizedLimit"))
        XCTAssertTrue(settings.contains("manualLayoutShortcut.v1"))
        XCTAssertTrue(settings.contains("disableAutomaticLayoutShortcut.v1"))
        XCTAssertTrue(coordinator.contains("registrations[action] = replacement"))
        XCTAssertTrue(coordinator.contains("func resetToDefaults()"))
        XCTAssertTrue(editor.contains("guard flushPendingSave() else { return }"))
        XCTAssertTrue(editor.contains("Text(\"Без папки\")"))
        XCTAssertTrue(editor.contains("windowShouldClose"))
        XCTAssertTrue(editor.contains("prepareForTermination"))
        XCTAssertTrue(editor.contains("Нажмите сниппет, чтобы изменить его справа"))
        XCTAssertTrue(editor.contains("Редактирование сниппета"))
        XCTAssertTrue(editor.contains("Сохраняется автоматически"))
        XCTAssertTrue(editor.contains("model.selectSnippet(snippet.id)"))
    }

    func testMenuPresentationIsWiredThroughEveryProductionPath() throws {
        let statusBar = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/StatusBarController.swift"),
            encoding: .utf8
        )
        let preferences = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/PreferencesWindow.swift"),
            encoding: .utf8
        )

        let appearance = try XCTUnwrap(statusBar.range(of: "MenuAppearance.applyEffectiveAppearance(to: menu)"))
        let popupBranch = try XCTUnwrap(statusBar.range(of: "if anchoredToStatusItem, let button = statusItem.button"))
        XCTAssertLessThan(appearance.lowerBound, popupBranch.lowerBound)

        XCTAssertTrue(statusBar.contains("MenuTitleFormatter.format(value, limit: Settings.menuTitleLength)"))
        XCTAssertTrue(statusBar.contains("let displayTitle = cleanTitle(title)"))
        XCTAssertTrue(statusBar.contains("cleanTitle(snippet.title + keyword)"))
        XCTAssertTrue(statusBar.contains("cleanTitle(clip.title)"))
        XCTAssertEqual(statusBar.components(separatedBy: "NSMenu(title:").count - 1, 1)
        XCTAssertTrue(statusBar.contains("private func makeMenu(title: String) -> NSMenu"))
        XCTAssertTrue(statusBar.contains("searchField.searchMenuTemplate = historySearchMenu()"))
        XCTAssertTrue(statusBar.contains("#selector(insertSearchFilter(_:))"))
        XCTAssertTrue(statusBar.contains("Storage.shared.menuSnippetSnapshot()"))

        XCTAssertTrue(preferences.contains("private struct NumericPreferenceRow: View"))
        XCTAssertTrue(preferences.contains("TextField(\"\", text: $text)"))
        XCTAssertTrue(preferences.contains("\"Размер истории\""))
        XCTAssertTrue(preferences.contains("\"Длина строки в меню\""))
        XCTAssertTrue(preferences.contains("MenuTitleFormatter.normalizedLimit(requested)"))
        XCTAssertTrue(preferences.contains("Settings.menuTitleLength = normalized"))
        XCTAssertTrue(preferences.contains("Storage.shared.deleteAllUserData()"))
        XCTAssertTrue(preferences.contains("Размер текста одной записи"))
        XCTAssertTrue(preferences.contains("Очищать незакреплённую историю при выходе"))
        XCTAssertTrue(preferences.contains("Запоминать последнюю раскладку для каждого приложения"))
        XCTAssertFalse(statusBar.contains("if let existing = folders.first?.id"))
        XCTAssertTrue(statusBar.contains("folderID: nil"))
    }

    func testPackageUsesSwift6AndNoHotKeyDependency() throws {
        let package = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(package.contains("swift-tools-version: 6.2"))
        XCTAssertTrue(package.contains("exact: \"7.11.1\""))
        XCTAssertFalse(package.contains("soffes/HotKey"))
        XCTAssertFalse(package.contains("import HotKey"))
    }

    func testReleaseScriptFailsClosedAndAvoidsDeepSigning() throws {
        let script = try String(
            contentsOf: repositoryRoot.appendingPathComponent("build-app.sh"),
            encoding: .utf8
        )

        let credentialPreflight = try XCTUnwrap(
            script.range(of: "notarytool history \"${NOTARY_ARGS[@]}\"")
        )
        let temporaryWorkspace = try XCTUnwrap(script.range(of: "WORK_DIR=$(mktemp -d"))
        let distMutation = try XCTUnwrap(script.range(of: "rm -rf dist/NeClip.app"))

        XCTAssertLessThan(credentialPreflight.lowerBound, temporaryWorkspace.lowerBound)
        XCTAssertLessThan(credentialPreflight.lowerBound, distMutation.lowerBound)
        XCTAssertTrue(script.contains("notarytool submit \"$ZIP\""))
        XCTAssertTrue(script.contains("NECLIP_NOTARY_KEY_PATH"))
        XCTAssertTrue(script.contains("NECLIP_NOTARY_KEY_ID"))
        XCTAssertTrue(script.contains("NECLIP_NOTARY_ISSUER"))
        XCTAssertTrue(script.contains("NOTARY_ARGS=(--key \"$KEY_PATH\" --key-id \"$KEY_ID\")"))
        XCTAssertTrue(script.contains("NOTARY_ARGS=(--keychain-profile \"$PROFILE\")"))
        XCTAssertTrue(script.contains("[[ -f \"$KEY_PATH\" ]]"))
        XCTAssertTrue(script.contains("stapler staple \"$APP\""))
        XCTAssertTrue(script.contains("stapler staple \"$DMG\""))
        XCTAssertTrue(script.contains("spctl --assess --type execute"))
        XCTAssertFalse(script.contains("codesign --deep"))
        XCTAssertTrue(script.contains("diskutil image create from"))
        XCTAssertTrue(script.contains("diskutil image attach --readOnly"))
        XCTAssertFalse(script.contains("hdiutil"))
        XCTAssertTrue(script.contains("(cd \"$WORK_DIR\" && shasum -a 256"))
    }

    func testGitHubIsTheOnlyPublicationAndUpdateSource() throws {
        let fileManager = FileManager.default
        XCTAssertFalse(fileManager.fileExists(atPath: repositoryRoot.appendingPathComponent("landing").path))

        let updater = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Sources/NeClip/UpdateChecker.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(updater.contains("https://affpapa.github.io/neclip/version.json"))
        XCTAssertTrue(updater.contains("/AffPapa/neclip/releases/download"))
        XCTAssertFalse(updater.contains("https://affpapa.org"))

        let website = try String(
            contentsOf: repositoryRoot.appendingPathComponent("docs/index.html"),
            encoding: .utf8
        )
        XCTAssertFalse(website.contains("https://affpapa.org"))
        XCTAssertTrue(website.contains("project.json"))
    }
}
