import AppKit

@MainActor
final class LayoutFeedbackHUD {
    static let shared = LayoutFeedbackHUD()

    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?

    func show(_ message: String) {
        dismissWork?.cancel()
        let panel = panel ?? makePanel()
        guard let label = panel.contentView?.viewWithTag(101) as? NSTextField else { return }
        label.stringValue = message
        label.sizeToFit()

        let width = min(520, max(260, label.frame.width + 52))
        let height: CGFloat = 52
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrame(
                NSRect(
                    x: visible.midX - width / 2,
                    y: visible.maxY - height - 42,
                    width: width,
                    height: height
                ),
                display: true
            )
        }
        label.frame = NSRect(x: 22, y: 15, width: width - 44, height: 22)
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak panel] in panel?.orderOut(nil) }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true

        let background = NSVisualEffectView(frame: panel.contentView?.bounds ?? .zero)
        background.autoresizingMask = [.width, .height]
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 14
        background.layer?.masksToBounds = true

        let label = NSTextField(labelWithString: "")
        label.tag = 101
        label.alignment = .center
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        background.addSubview(label)
        panel.contentView = background
        self.panel = panel
        return panel
    }
}
