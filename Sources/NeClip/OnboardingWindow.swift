import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private let accessibilityCompletedKey = "onboardingCompletedV2"
    private let clipboardCompletedKey = "onboardingClipboardCompletedV3"
    private var window: NSWindow?
    private var startHistory: (() -> Void)?

    private init() {}

    /// Returns true when monitoring is intentionally delayed until the user
    /// has seen the pasteboard privacy explanation.
    @discardableResult
    func showIfNeeded(startHistory: @escaping () -> Void) -> Bool {
        let defaults = UserDefaults.standard
        if PasteService.isAccessibilityTrusted {
            defaults.set(true, forKey: accessibilityCompletedKey)
        }

        let clipboardNeedsExplanation = ClipboardAccess.current.needsFirstRunExplanation
            && !defaults.bool(forKey: clipboardCompletedKey)
        let accessibilityNeedsExplanation = !PasteService.isAccessibilityTrusted
            && !defaults.bool(forKey: accessibilityCompletedKey)
        guard clipboardNeedsExplanation || accessibilityNeedsExplanation else {
            if ClipboardAccess.current == .allowed || ClipboardAccess.current == .unrestricted {
                defaults.set(true, forKey: clipboardCompletedKey)
            }
            return false
        }
        self.startHistory = startHistory
        show()
        return true
    }

    func show() {
        if window == nil {
            let view = OnboardingView(
                requestAutoPaste: { PasteService.requestAccessibility() },
                openClipboardPrivacy: { ClipboardAccess.openPrivacySettings() },
                complete: { [weak self] in self?.complete() }
            )
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Добро пожаловать в NeClip"
            window.styleMask = [.titled]
            window.setContentSize(NSSize(width: 560, height: 540))
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func complete() {
        UserDefaults.standard.set(true, forKey: accessibilityCompletedKey)
        UserDefaults.standard.set(true, forKey: clipboardCompletedKey)
        window?.orderOut(nil)
        let action = startHistory
        startHistory = nil
        action?()
    }
}

private struct OnboardingView: View {
    let requestAutoPaste: () -> Void
    let openClipboardPrivacy: () -> Void
    let complete: () -> Void
    @State private var accessibilityTrusted = PasteService.isAccessibilityTrusted
    @State private var clipboardAccess = ClipboardAccess.current

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.tint)
                Text("История буфера — в строке меню")
                    .font(.title2.bold())
                Text("NeClip хранит данные только на этом Mac. Аккаунт, облако и телеметрия не нужны.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                shortcut("⌘⇧V", "Открыть историю")
                shortcut("Поиск → ↩", "Найти и вставить")
                shortcut("⌘⇧B", "Открыть готовые сниппеты")
                shortcut(Settings.manualLayoutShortcut.displayString, "Исправить неверную раскладку")
                shortcut(Settings.disableAutomaticLayoutShortcut.displayString, "Быстро выключить автоисправление")
            }
            .padding(14)
            .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))

            permissionBlock(
                title: clipboardTitle,
                detail: clipboardDetail,
                symbol: clipboardAccess == .denied ? "exclamationmark.shield.fill" : "checkmark.shield.fill",
                color: clipboardAccess == .denied ? .orange : .green
            )

            permissionBlock(
                title: accessibilityTrusted ? "Автовставка уже разрешена" : "Автовставка — по желанию",
                detail: accessibilityTrusted
                    ? "NeClip найден в «Универсальном доступе». Ничего добавлять не нужно."
                    : "Без «Универсального доступа» выбранный элемент просто копируется — вставьте его обычным ⌘V. Нажимать + не нужно.",
                symbol: accessibilityTrusted ? "checkmark.circle.fill" : "hand.raised.fill",
                color: accessibilityTrusted ? .green : .secondary
            )

            HStack(spacing: 10) {
                if clipboardAccess == .denied {
                    Button("Открыть конфиденциальность…", action: openClipboardPrivacy)
                } else if !accessibilityTrusted {
                    Button("Разрешить автовставку…", action: requestAutoPaste)
                }
                Spacer()
                Button(clipboardAccess == .denied ? "Продолжить без истории" : "Начать работу", action: complete)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 560, height: 540)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityTrusted = PasteService.isAccessibilityTrusted
            clipboardAccess = ClipboardAccess.current
        }
    }

    private var clipboardTitle: String {
        switch clipboardAccess {
        case .unrestricted, .allowed: "История буфера разрешена"
        case .needsChoice: "Разрешите чтение буфера для истории"
        case .denied: "История заблокирована в macOS"
        }
    }

    private var clipboardDetail: String {
        switch clipboardAccess {
        case .unrestricted, .allowed:
            "NeClip сможет замечать новые копирования в фоне."
        case .needsChoice:
            "После начала macOS может показать системный запрос. Для непрерывной истории выберите «Всегда разрешать»."
        case .denied:
            "Откройте «Конфиденциальность и безопасность» → «Буфер обмена» и разрешите NeClip, затем вернитесь."
        }
    }

    private func permissionBlock(title: String, detail: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func shortcut(_ keys: String, _ description: String) -> some View {
        HStack(spacing: 12) {
            Text(keys)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .frame(width: 86, alignment: .leading)
            Text(description)
        }
    }
}
