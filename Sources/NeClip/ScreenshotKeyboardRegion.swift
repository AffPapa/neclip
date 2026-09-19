import AppKit
import Carbon

/// Shared geometry for capture (bottom-left origin) and markup (top-left).
enum ScreenshotKeyboardRegion {
    static let help = "Стрелки — переместить; Shift со стрелками — размер; Option — шаг 10; Return — подтвердить; Escape — отмена."

    static func delta(for event: NSEvent, flipped: Bool) -> (x: CGFloat, y: CGFloat)? {
        guard event.modifierFlags.intersection([.command, .control]).isEmpty else { return nil }
        let step: CGFloat = event.modifierFlags.contains(.option) ? 10 : 1
        switch Int(event.keyCode) {
        case kVK_LeftArrow: return (-step, 0)
        case kVK_RightArrow: return (step, 0)
        case kVK_UpArrow: return (0, flipped ? -step : step)
        case kVK_DownArrow: return (0, flipped ? step : -step)
        default: return nil
        }
    }

    static func initial(in bounds: CGRect) -> CGRect {
        let size = CGSize(width: min(bounds.width, max(2, min(160, bounds.width / 3))),
                          height: min(bounds.height, max(2, min(100, bounds.height / 3))))
        return CGRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                      width: size.width, height: size.height).integral.intersection(bounds)
    }

    static func adjusted(_ rect: CGRect, dx: CGFloat, dy: CGFloat, resizing: Bool, in bounds: CGRect) -> CGRect {
        var result = rect.isEmpty ? initial(in: bounds) : rect
        if resizing {
            result.size.width = min(bounds.maxX - result.minX, max(min(2, bounds.width), result.width + dx))
            result.size.height = min(bounds.maxY - result.minY, max(min(2, bounds.height), result.height + dy))
        } else {
            result.origin.x = min(max(bounds.minX, result.minX + dx), bounds.maxX - result.width)
            result.origin.y = min(max(bounds.minY, result.minY + dy), bounds.maxY - result.height)
        }
        return result
    }

    static func description(_ rect: CGRect, in bounds: CGRect, flipped: Bool) -> String {
        guard !rect.isEmpty else { return "Область не задана. Нажмите стрелку или Return." }
        let y = flipped ? rect.minY - bounds.minY : bounds.maxY - rect.maxY
        return "Слева \(Int(rect.minX - bounds.minX)), сверху \(Int(y)); ширина \(Int(rect.width)), высота \(Int(rect.height))."
    }
}

@MainActor
enum ScreenshotRegionAccessibility {
    static func configure(_ view: NSView, label: String, confirmName: String,
                          adjust: @escaping @MainActor (CGFloat, CGFloat, Bool) -> Bool,
                          confirm: @escaping @MainActor () -> Bool) {
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.group)
        view.setAccessibilityLabel(label)
        view.setAccessibilityHelp(ScreenshotKeyboardRegion.help)
        // Screen-reader users can perform every rectangle operation without
        // passing raw arrow keys through VoiceOver.
        let operations: [(String, CGFloat, CGFloat, Bool)] = [
            ("Влево на 10", -10, 0, false), ("Вправо на 10", 10, 0, false),
            ("Вверх на 10", 0, -10, false), ("Вниз на 10", 0, 10, false),
            ("Увеличить ширину на 10", 10, 0, true), ("Уменьшить ширину на 10", -10, 0, true),
            ("Увеличить высоту на 10", 0, 10, true), ("Уменьшить высоту на 10", 0, -10, true)
        ]
        var actions = operations.map { name, dx, dy, resize in
            NSAccessibilityCustomAction(name: name, handler: {
                MainActor.assumeIsolated { adjust(dx, dy, resize) }
            })
        }
        actions.insert(NSAccessibilityCustomAction(name: confirmName, handler: {
            MainActor.assumeIsolated { confirm() }
        }), at: 0)
        view.setAccessibilityCustomActions(actions)
    }

    static func announce(_ message: String) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.low.rawValue])
    }

    static func update(_ view: NSView, value: String, announce: Bool = true) {
        view.setAccessibilityValue(value)
        NSAccessibility.post(element: view, notification: .valueChanged)
        if announce { self.announce(value) }
    }
}
