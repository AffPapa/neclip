import AppKit
import Carbon
import XCTest
@testable import NeClip

final class LiveLayoutTests: XCTestCase {
    @MainActor
    func testLateRecoveredCandidateCannotCancelNewerScheduledAttempt() async {
        let scheduler = LiveLayoutAttemptScheduler()
        let newer = expectation(description: "newest word still corrected")
        scheduler.enqueue(sequence: 6, currentSequence: 6, delay: 0.01) { newer.fulfill() }
        scheduler.enqueue(sequence: 5, currentSequence: 6, delay: 0.01) { XCTFail("stale recovered candidate ran") }
        await fulfillment(of: [newer], timeout: 1)
        scheduler.cancel()
    }

    @MainActor
    func testProductionDictionaryRecognizesBothCorrectionExamples() throws {
        let dictionary = LayoutDictionary()
        for (typed, converted, source, target) in [("руддщ", "hello", "ru", "en"), ("ghbdtn", "привет", "en", "ru"), ("[jxe", "хочу", "en", "ru")] {
            guard let known = dictionary.isKnown(typed, language: source),
                  let convertedKnown = dictionary.isKnown(converted, language: target) else {
                throw XCTSkip("English and Russian system spelling dictionaries required")
            }
            XCTAssertEqual(AutoLayoutDecisionPolicy.decide(typed: typed, converted: converted,
                                                           typedIsKnownWord: known, convertedIsKnownWord: convertedKnown), .correct, typed)
        }
    }

    private final class Editor {
        var value: String
        var range: CFRange
        var writes = 0
        var beforeSelect: (() -> Void)?
        var writeSucceeds = true
        init(_ value: String) {
            self.value = value
            range = CFRange(location: (value as NSString).length, length: 0)
        }
        var access: LiveLayoutRangeAccess {
            LiveLayoutRangeAccess(selection: { self.range }, text: { range in
                let ns = self.value as NSString
                guard range.location >= 0, range.length >= 0, range.location + range.length <= ns.length else { return nil }
                return ns.substring(with: NSRange(location: range.location, length: range.length))
            }, select: { range in
                self.beforeSelect?()
                self.range = range
                return true
            }, replaceSelection: { text in
                self.writes += 1
                guard self.writeSucceeds else { return false }
                self.value = (self.value as NSString).replacingCharacters(in: NSRange(location: self.range.location, length: self.range.length), with: text)
                self.range = CFRange(location: self.range.location + (text as NSString).length, length: 0)
                return true
            })
        }
    }

    func testLastKeyNotYetVisibleRetriesThenCorrectsWithoutSpace() {
        let editor = Editor("рудд")
        let first = editor.access.replaceTail(expected: "руддщ", replacement: "hello")
        XCTAssertEqual(first, .notReady)
        XCTAssertNotNil(LiveLayoutRetryPolicy.delay(after: first, attempt: 0, sequence: 5, currentSequence: 5))
        XCTAssertEqual(editor.writes, 0)
        editor.value = "руддщ"
        editor.range.location = 5
        XCTAssertEqual(editor.access.replaceTail(expected: "руддщ", replacement: "hello"), .replaced)
        XCTAssertEqual(editor.value, "hello")
        XCTAssertEqual(editor.range.location, 5)
        XCTAssertEqual(editor.writes, 1)
    }

    func testRetryIsBoundedAndNeverRepeatsMutationOrStaleKey() {
        for result in [LiveLayoutReplacementResult.replaced, .rejected, .uncertain] {
            XCTAssertNil(LiveLayoutRetryPolicy.delay(after: result, attempt: 0, sequence: 5, currentSequence: 5))
        }
        XCTAssertNil(LiveLayoutRetryPolicy.delay(after: .notReady, attempt: 0, sequence: 5, currentSequence: 6))
        XCTAssertNil(LiveLayoutRetryPolicy.delay(after: .notReady, attempt: 3, sequence: 5, currentSequence: 5))
        XCTAssertLessThan(LiveLayoutRetryPolicy.initialDelay + LiveLayoutRetryPolicy.retryDelays.reduce(0, +), 0.2)
    }

    func testMultilineLongDocumentPreservesPrefixSuffixAndUTF16Caret() {
        let prefix = String(repeating: "🦊 Сохранить эту строку\n", count: 200)
        let editor = Editor(prefix + "руддщ\nСледующая строка")
        editor.range.location = (prefix as NSString).length + 5
        XCTAssertEqual(editor.access.replaceTail(expected: "руддщ", replacement: "hello"), .replaced)
        XCTAssertEqual(editor.value, prefix + "hello\nСледующая строка")
        XCTAssertEqual(editor.range.location, (prefix as NSString).length + 5)
    }

    func testCannotCorrectSuffixAfterMissedLeadingKeyOrExistingSelection() {
        let editor = Editor("prefixруддщ")
        XCTAssertEqual(editor.access.replaceTail(expected: "руддщ", replacement: "hello"), .rejected)
        editor.value = "руддщ"
        editor.range = CFRange(location: 0, length: 5)
        XCTAssertEqual(editor.access.replaceTail(expected: "руддщ", replacement: "hello"), .rejected)
        XCTAssertEqual(editor.writes, 0)
    }

    func testConcurrentEditBetweenReadAndSelectDoesNotGetOverwritten() {
        let editor = Editor("руддщ")
        editor.beforeSelect = { editor.value = "other" }
        XCTAssertEqual(editor.access.replaceTail(expected: "руддщ", replacement: "hello"), .rejected)
        XCTAssertEqual(editor.value, "other")
        XCTAssertEqual(editor.writes, 0)
        XCTAssertEqual(editor.range.location, 5)
        XCTAssertEqual(editor.range.length, 0)
    }

    func testRejectedSecondManualCommandKeepsFirstTransactionSuspended() {
        var suspension = LayoutManualSuspension()
        suspension.begin()
        suspension.begin()
        suspension.end()
        XCTAssertTrue(suspension.isSuspended)
        suspension.end()
        XCTAssertFalse(suspension.isSuspended)
        suspension.end()
        XCTAssertFalse(suspension.isSuspended)
    }

    func testFailedWriteIsTerminalAndRestoresOwnSelection() {
        let editor = Editor("руддщ")
        editor.writeSucceeds = false
        XCTAssertEqual(editor.access.replaceTail(expected: "руддщ", replacement: "hello"), .uncertain)
        XCTAssertEqual(editor.value, "руддщ")
        XCTAssertEqual(editor.range.location, 5)
        XCTAssertEqual(editor.range.length, 0)
    }

    @MainActor
    func testNativeRichTextViewRetainsFormattingOutsideToken() {
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let prefix = "Сохранить формат\n"
        let attributed = NSMutableAttributedString(string: prefix + "руддщ\nконец")
        attributed.addAttribute(.foregroundColor, value: NSColor.red, range: NSRange(location: 0, length: (prefix as NSString).length))
        editor.textStorage?.setAttributedString(attributed)
        editor.setSelectedRange(NSRange(location: (prefix as NSString).length + 5, length: 0))
        let access = LiveLayoutRangeAccess(selection: {
            let range = editor.selectedRange()
            return CFRange(location: range.location, length: range.length)
        }, text: { range in
            let text = editor.string as NSString
            guard range.location + range.length <= text.length else { return nil }
            return text.substring(with: NSRange(location: range.location, length: range.length))
        }, select: { range in
            editor.setSelectedRange(NSRange(location: range.location, length: range.length)); return true
        }, replaceSelection: { text in
            editor.insertText(text, replacementRange: editor.selectedRange()); return true
        })
        XCTAssertEqual(access.replaceTail(expected: "руддщ", replacement: "hello"), .replaced)
        XCTAssertEqual(editor.string, prefix + "hello\nконец")
        XCTAssertEqual(editor.textStorage?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .red)
    }

    private final class CapturedCandidates: @unchecked Sendable {
        var values: [AutoLayoutBoundary] = []
    }

    func testFocusRecoveryRetainsFirstKeystrokesAndRejectsStaleSnapshot() throws {
        let captured = CapturedCandidates()
        let monitor = AutoLayoutEventMonitor(manualShortcut: ShortcutDescriptor(keyCode: 40, modifiers: [.command, .option]),
                                            onBoundary: { captured.values.append($0) }, onContextInvalidated: {})
        let codes: [UInt16] = [4, 14, 37, 37, 31]
        for code in codes {
            let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true))
            event.flags = []
            monitor.handle(type: .keyDown, event: event)
        }
        let pending = try XCTUnwrap(monitor.pendingInput())
        XCTAssertEqual(pending.strokes.map(\.keyCode), codes)
        let valid = Set(pending.strokes)
        XCTAssertFalse(monitor.updateContext(sourceID: "ru", pid: 123, contextID: 1, validStrokes: valid,
                                             boundaryStrokes: [], recovering: pending, expectedSequence: pending.sequence - 1))
        XCTAssertTrue(captured.values.isEmpty)
        XCTAssertTrue(monitor.updateContext(sourceID: "ru", pid: 123, contextID: 2, validStrokes: valid,
                                            boundaryStrokes: [], recovering: pending))
        XCTAssertEqual(captured.values.last?.strokes.map(\.keyCode), codes)
        XCTAssertEqual(captured.values.last?.isBoundary, false)
        monitor.invalidateContext()
        XCTAssertNil(monitor.pendingInput())
    }

    func testProductionEventHandlerEmitsOnLettersAndBackspaceWithoutBoundary() throws {
        let captured = CapturedCandidates()
        let monitor = AutoLayoutEventMonitor(manualShortcut: ShortcutDescriptor(keyCode: 40, modifiers: [.command, .option]),
                                            onBoundary: { captured.values.append($0) }, onContextInvalidated: {})
        let codes: [UInt16] = [4, 14, 37, 37, 31] // physical H E L L O
        monitor.updateContext(sourceID: "ru", pid: 123, contextID: 1,
                              validStrokes: Set(codes.map { LayoutTypedStroke(keyCode: $0, shift: false, capsLock: false) }), boundaryStrokes: [])
        for code in codes {
            let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true))
            event.flags = []
            monitor.handle(type: .keyDown, event: event)
        }
        XCTAssertEqual(captured.values.map { $0.strokes.count }, [4, 5])
        XCTAssertTrue(captured.values.allSatisfy { !$0.isBoundary && $0.terminator == nil })
        let deletion = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: UInt16(kVK_Delete), keyDown: true))
        deletion.flags = []
        monitor.handle(type: .keyDown, event: deletion)
        XCTAssertEqual(captured.values.last?.strokes.count, 4)
        XCTAssertEqual(captured.values.last?.sequence, monitor.currentSequence())
        monitor.invalidateContext()
        XCTAssertEqual(captured.values.count, 3)
    }
}
