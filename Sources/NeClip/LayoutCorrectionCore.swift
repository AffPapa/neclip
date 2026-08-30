import Foundation

enum LayoutDirection: Equatable {
    case englishToRussian
    case russianToEnglish
}

struct LayoutConversion: Equatable {
    let original: String
    let converted: String
    let direction: LayoutDirection
    let sourceID: String
    let targetID: String
}

struct LayoutCharacterMaps {
    let englishToRussian: [Character: Character]
    let russianToEnglish: [Character: Character]
    let englishSourceID: String
    let russianSourceID: String

    func convert(_ text: String) -> LayoutConversion? {
        let direction = LayoutTextPolicy.direction(for: text)
        guard let direction else { return nil }
        let split = LayoutTextPolicy.splitTrailingLiteralPunctuation(text)

        let map: [Character: Character]
        let sourceID: String
        let targetID: String
        switch direction {
        case .englishToRussian:
            map = englishToRussian
            sourceID = englishSourceID
            targetID = russianSourceID
        case .russianToEnglish:
            map = russianToEnglish
            sourceID = russianSourceID
            targetID = englishSourceID
        }

        var mapped = 0
        let convertedCore = String(split.core.map { character in
            guard let replacement = map[character] else { return character }
            mapped += 1
            return replacement
        })
        let converted = convertedCore + split.suffix
        guard mapped > 0, converted != text else { return nil }
        return LayoutConversion(
            original: text,
            converted: converted,
            direction: direction,
            sourceID: sourceID,
            targetID: targetID
        )
    }
}

enum LayoutTextPolicy {
    private static let trailingLiteralPunctuation: Set<Character> = [",", ".", "!", "?", ";", ":", ")"]

    static func splitTrailingLiteralPunctuation(_ text: String) -> (core: String, suffix: String) {
        var core = text[...]
        while let last = core.last, trailingLiteralPunctuation.contains(last) {
            core = core.dropLast()
        }
        return (String(core), String(text.dropFirst(core.count)))
    }

    static func direction(for text: String) -> LayoutDirection? {
        var latin = 0
        var cyrillic = 0
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0041...0x005A, 0x0061...0x007A:
                latin += 1
            case 0x0400...0x04FF:
                cyrillic += 1
            default:
                break
            }
        }
        guard latin > 0 || cyrillic > 0 else { return nil }
        guard latin == 0 || cyrillic == 0 else { return nil }
        return latin > 0 ? .englishToRussian : .russianToEnglish
    }

    static func isAutoCandidate(_ text: String) -> Bool {
        guard (4...32).contains(text.count), text.allSatisfy(\.isLetter) else { return false }
        guard direction(for: text) != nil else { return false }
        if text == text.uppercased(), text != text.lowercased() { return false }
        for (index, character) in text.enumerated() where index > 0 && character.isUppercase {
            return false
        }
        return true
    }
}

enum AutoLayoutVerdict: Equatable {
    case correct
    case stay
}

enum AutoLayoutDecisionPolicy {
    static func decide(
        typed: String,
        converted: String,
        typedIsKnownWord: Bool,
        convertedIsKnownWord: Bool
    ) -> AutoLayoutVerdict {
        guard LayoutTextPolicy.isAutoCandidate(typed),
              LayoutTextPolicy.isAutoCandidate(converted),
              convertedIsKnownWord,
              !typedIsKnownWord else { return .stay }
        return .correct
    }
}

enum LayoutWholeValueCASPolicy {
    static func shouldRollback(currentValue: String?, ownReplacement: String) -> Bool {
        currentValue == ownReplacement
    }
}

struct LayoutTypedStroke: Equatable, Sendable {
    let keyCode: UInt16
    let shift: Bool
    let capsLock: Bool
}

struct LayoutStrokeTranslation: Equatable {
    let original: String
    let converted: String
    let sourceID: String
    let targetID: String
    let sourceLanguage: String
    let targetLanguage: String
}

struct AutoTypingBuffer {
    private(set) var strokes: [LayoutTypedStroke] = []
    let capacity: Int

    init(capacity: Int = 64) {
        self.capacity = max(1, capacity)
    }

    mutating func append(_ stroke: LayoutTypedStroke) -> Bool {
        guard strokes.count < capacity else {
            strokes.removeAll(keepingCapacity: true)
            return false
        }
        strokes.append(stroke)
        return true
    }

    mutating func backspace() {
        if strokes.isEmpty {
            reset()
        } else {
            strokes.removeLast()
        }
    }

    mutating func takeAtBoundary() -> [LayoutTypedStroke] {
        let result = strokes
        strokes.removeAll(keepingCapacity: true)
        return result
    }

    mutating func reset() {
        strokes.removeAll(keepingCapacity: true)
    }
}

enum LayoutProtectedApplicationPolicy {
    static let sensitiveBundleIDs: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.apple.Passwords",
        "com.apple.keychainaccess",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "org.keepassxc.keepassxc"
    ]

    static let protectedBundleIDs: Set<String> = sensitiveBundleIDs.union([
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "net.kovidgoyal.kitty",
        "dev.warp.Warp-Stable",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "com.jetbrains.intellij",
        "com.jetbrains.AppCode",
        "com.microsoft.rdc.macos",
        "com.microsoft.rdc.mac",
        "com.teamviewer.TeamViewer",
        "com.anydesk.AnyDesk"
    ])

    static func blocksAutomatic(bundleID: String?, userExcluded: Set<String>) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return true }
        if protectedBundleIDs.contains(bundleID) || userExcluded.contains(bundleID) { return true }
        if bundleID.hasPrefix("com.jetbrains.") { return true }
        return false
    }

    static func blocksManual(bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return true }
        return sensitiveBundleIDs.contains(bundleID)
    }
}
