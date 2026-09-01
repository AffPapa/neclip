import Carbon
import Foundation

@MainActor
final class KeyboardLayoutService {
    static let shared = KeyboardLayoutService()

    struct LayoutPair {
        fileprivate let english: Source
        fileprivate let russian: Source

        var englishID: String { english.id }
        var russianID: String { russian.id }
    }

    fileprivate struct Source {
        let inputSource: TISInputSource
        let id: String
        let name: String
        let language: String
        let layoutData: Data
    }

    private var cachedPair: LayoutPair?
    private var cachedMaps: LayoutCharacterMaps?
    private var cachedValidLetterKeyCodes: [String: Set<UInt16>] = [:]

    func layoutPair() -> LayoutPair? {
        if let cachedPair { return cachedPair }
        let sources = enabledKeyboardLayouts()
        guard let english = preferredSource(language: "en", from: sources),
              let russian = preferredSource(language: "ru", from: sources) else { return nil }
        let pair = LayoutPair(english: english, russian: russian)
        cachedPair = pair
        return pair
    }

    func characterMaps() -> LayoutCharacterMaps? {
        if let cachedMaps { return cachedMaps }
        guard let pair = layoutPair() else { return nil }
        var englishToRussian: [Character: Character] = [:]
        var russianToEnglish: [Character: Character] = [:]
        var ambiguousEnglish = Set<Character>()
        var ambiguousRussian = Set<Character>()

        for keyCode in UInt16(0)..<UInt16(128) {
            for (shift, caps) in [(false, false), (true, false), (false, true), (true, true)] {
                guard let english = translate(keyCode: keyCode, shift: shift, capsLock: caps, data: pair.english.layoutData),
                      let russian = translate(keyCode: keyCode, shift: shift, capsLock: caps, data: pair.russian.layoutData) else {
                    continue
                }
                insert(english, mapsTo: russian, into: &englishToRussian, ambiguous: &ambiguousEnglish)
                insert(russian, mapsTo: english, into: &russianToEnglish, ambiguous: &ambiguousRussian)
            }
        }

        for key in ambiguousEnglish { englishToRussian.removeValue(forKey: key) }
        for key in ambiguousRussian { russianToEnglish.removeValue(forKey: key) }
        guard !englishToRussian.isEmpty, !russianToEnglish.isEmpty else { return nil }
        let maps = LayoutCharacterMaps(
            englishToRussian: englishToRussian,
            russianToEnglish: russianToEnglish,
            englishSourceID: pair.english.id,
            russianSourceID: pair.russian.id
        )
        cachedMaps = maps
        return maps
    }

    func convert(_ text: String) -> LayoutConversion? {
        characterMaps()?.convert(text)
    }

    func translate(strokes: [LayoutTypedStroke], sourceID: String) -> LayoutStrokeTranslation? {
        guard !strokes.isEmpty, let pair = layoutPair() else { return nil }
        let source: Source
        let target: Source
        if sourceID == pair.english.id {
            source = pair.english
            target = pair.russian
        } else if sourceID == pair.russian.id {
            source = pair.russian
            target = pair.english
        } else {
            return nil
        }

        var original = ""
        var converted = ""
        for stroke in strokes {
            guard let sourceCharacter = translate(
                keyCode: stroke.keyCode,
                shift: stroke.shift,
                capsLock: stroke.capsLock,
                data: source.layoutData
            ), let targetCharacter = translate(
                keyCode: stroke.keyCode,
                shift: stroke.shift,
                capsLock: stroke.capsLock,
                data: target.layoutData
            ), sourceCharacter.isLetter, targetCharacter.isLetter else { return nil }
            original.append(sourceCharacter)
            converted.append(targetCharacter)
        }
        guard original.count == strokes.count, converted.count == strokes.count else { return nil }
        return LayoutStrokeTranslation(
            original: original,
            converted: converted,
            sourceID: source.id,
            targetID: target.id,
            sourceLanguage: source.language,
            targetLanguage: target.language
        )
    }

    func validLetterKeyCodes(sourceID: String) -> Set<UInt16> {
        if let cached = cachedValidLetterKeyCodes[sourceID] { return cached }
        guard let pair = layoutPair() else { return [] }
        let source: Source
        let target: Source
        if sourceID == pair.english.id {
            source = pair.english
            target = pair.russian
        } else if sourceID == pair.russian.id {
            source = pair.russian
            target = pair.english
        } else {
            return []
        }
        let valid = Set((UInt16(0)..<UInt16(128)).filter { keyCode in
            guard let a = translate(keyCode: keyCode, shift: false, capsLock: false, data: source.layoutData),
                  let b = translate(keyCode: keyCode, shift: false, capsLock: false, data: target.layoutData) else {
                return false
            }
            return a.isLetter && b.isLetter
        })
        cachedValidLetterKeyCodes[sourceID] = valid
        return valid
    }

    func currentSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              (property(source, kTISPropertyInputSourceType) as String?) == kTISTypeKeyboardLayout as String,
              (property(source, kTISPropertyInputSourceCategory) as String?) == kTISCategoryKeyboardInputSource as String else {
            return nil
        }
        return property(source, kTISPropertyInputSourceID) as String?
    }

    /// Accepts selectable input methods as well as direct keyboard layouts.
    /// Automatic correction deliberately keeps using the stricter method above
    /// because it requires keyboard-layout translation data.
    func currentSelectableSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let id: String = property(source, kTISPropertyInputSourceID),
              (property(source, kTISPropertyInputSourceIsSelectCapable) as Bool?) != false else {
            return nil
        }
        return id
    }

    @discardableResult
    func selectSource(id: String) -> Bool {
        guard let source = enabledKeyboardLayouts().first(where: { $0.id == id }) else { return false }
        guard TISSelectInputSource(source.inputSource) == noErr else { return false }
        return currentSourceID() == id
    }

    @discardableResult
    func selectSelectableSource(id: String) -> Bool {
        guard let raw = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource],
              let source = raw.first(where: {
                (property($0, kTISPropertyInputSourceID) as String?) == id
                    && (property($0, kTISPropertyInputSourceIsEnabled) as Bool?) == true
                    && (property($0, kTISPropertyInputSourceIsSelectCapable) as Bool?) == true
              }), TISSelectInputSource(source) == noErr else { return false }
        return currentSelectableSourceID() == id
    }

    func invalidate() {
        cachedPair = nil
        cachedMaps = nil
        cachedValidLetterKeyCodes = [:]
    }

    private func enabledKeyboardLayouts() -> [Source] {
        guard let raw = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return []
        }
        return raw.compactMap { source in
            guard (property(source, kTISPropertyInputSourceType) as String?) == kTISTypeKeyboardLayout as String,
                  (property(source, kTISPropertyInputSourceCategory) as String?) == kTISCategoryKeyboardInputSource as String,
                  (property(source, kTISPropertyInputSourceIsEnabled) as Bool?) == true,
                  (property(source, kTISPropertyInputSourceIsSelectCapable) as Bool?) == true,
                  let id: String = property(source, kTISPropertyInputSourceID),
                  let data = layoutData(source),
                  let language = (property(source, kTISPropertyInputSourceLanguages) as [String]?)?.first else {
                return nil
            }
            let name: String = property(source, kTISPropertyLocalizedName) ?? id
            return Source(
                inputSource: source,
                id: id,
                name: name,
                language: String(language.prefix(2)).lowercased(),
                layoutData: data
            )
        }
    }

    private func preferredSource(language: String, from sources: [Source]) -> Source? {
        let candidates = sources.filter { $0.language == language }
        if let currentID = currentSourceID(), let current = candidates.first(where: { $0.id == currentID }) {
            return current
        }
        let preferredIDs: [String]
        if language == "en" {
            preferredIDs = ["com.apple.keylayout.ABC", "com.apple.keylayout.US"]
        } else {
            preferredIDs = ["com.apple.keylayout.RussianWin", "com.apple.keylayout.Russian"]
        }
        for id in preferredIDs {
            if let exact = candidates.first(where: { $0.id == id }) { return exact }
        }
        return candidates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.first
    }

    private func layoutData(_ source: TISInputSource) -> Data? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        return Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
    }

    private func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
    }

    private func insert(
        _ source: Character,
        mapsTo target: Character,
        into map: inout [Character: Character],
        ambiguous: inout Set<Character>
    ) {
        if let existing = map[source], existing != target {
            ambiguous.insert(source)
        } else {
            map[source] = target
        }
    }

    private func translate(
        keyCode: UInt16,
        shift: Bool,
        capsLock: Bool,
        data: Data
    ) -> Character? {
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        var modifiers: UInt32 = 0
        if shift { modifiers |= UInt32(shiftKey >> 8) & 0xff }
        if capsLock { modifiers |= UInt32(alphaLock >> 8) & 0xff }

        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return OSStatus(paramErr)
            }
            return UCKeyTranslate(
                base,
                keyCode,
                UInt16(kUCKeyActionDown),
                modifiers,
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysMask),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, deadKeyState == 0, length == 1,
              let scalar = UnicodeScalar(characters[0]), !CharacterSet.controlCharacters.contains(scalar) else {
            return nil
        }
        return Character(scalar)
    }
}
