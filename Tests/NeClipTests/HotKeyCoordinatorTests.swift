import Carbon.HIToolbox
import Foundation
import XCTest
@testable import NeClip

final class FakeHotKeyRegistry: @unchecked Sendable, HotKeyRegistrationCreating {
    private final class Token: HotKeyRegistrationToken {
        private let shortcut: ShortcutDescriptor
        private weak var registry: FakeHotKeyRegistry?

        init(shortcut: ShortcutDescriptor, registry: FakeHotKeyRegistry) {
            self.shortcut = shortcut
            self.registry = registry
        }

        deinit { registry?.release(shortcut) }
    }

    private let lock = NSLock()
    private var activeStorage: Set<ShortcutDescriptor> = []
    private var blockedStorage: Set<ShortcutDescriptor> = []

    var active: Set<ShortcutDescriptor> { lock.withLock { activeStorage } }

    func setBlocked(_ shortcuts: Set<ShortcutDescriptor>) {
        lock.withLock { blockedStorage = shortcuts }
    }

    func makeRegistration(
        shortcut: ShortcutDescriptor,
        identifier: UInt32,
        action: @escaping GlobalHotKey.Action
    ) throws -> any HotKeyRegistrationToken {
        try lock.withLock {
            guard !blockedStorage.contains(shortcut), !activeStorage.contains(shortcut) else {
                throw GlobalHotKeyRegistrationError.alreadyRegistered(OSStatus(eventHotKeyExistsErr))
            }
            activeStorage.insert(shortcut)
            return Token(shortcut: shortcut, registry: self)
        }
    }

    private func release(_ shortcut: ShortcutDescriptor) {
        _ = lock.withLock { activeStorage.remove(shortcut) }
    }
}

final class HotKeyCoordinatorTests: XCTestCase {
    private let alternateHistory = ShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_H),
        modifiers: [.control, .shift]
    )

    @MainActor
    func testUpdateKeepsWorkingShortcutWhenCandidateIsUnavailable() {
        let registry = FakeHotKeyRegistry()
        let coordinator = makeCoordinator(registry: registry)
        start(coordinator)
        registry.setBlocked([alternateHistory])

        guard case .rejected = coordinator.update(.history, to: alternateHistory) else {
            return XCTFail("Unavailable candidate must be rejected")
        }
        XCTAssertEqual(coordinator.shortcut(for: .history), .historyDefault)
        XCTAssertTrue(registry.active.contains(.historyDefault))
    }

    @MainActor
    func testEveryOtherNeClipActionParticipatesInConflictValidation() {
        let registry = FakeHotKeyRegistry()
        let coordinator = makeCoordinator(registry: registry)
        start(coordinator)

        for action in NeClipShortcutAction.allCases where action != .history {
            guard case .rejected = coordinator.update(.history, to: coordinator.shortcut(for: action)) else {
                return XCTFail("\(action) must conflict with history")
            }
        }
    }

    @MainActor
    func testSameCandidateRetriesAfterStartupConflictDisappears() {
        let registry = FakeHotKeyRegistry()
        registry.setBlocked([.defaultManualLayout])
        let coordinator = makeCoordinator(registry: registry)
        start(coordinator)
        XCTAssertFalse(registry.active.contains(.defaultManualLayout))

        registry.setBlocked([])
        XCTAssertEqual(coordinator.update(.manualCorrection, to: .defaultManualLayout), .applied)
        XCTAssertTrue(registry.active.contains(.defaultManualLayout))
    }

    @MainActor
    func testResetRestoresAllFiveDefaultsAsOneTransaction() {
        let registry = FakeHotKeyRegistry()
        let coordinator = makeCoordinator(registry: registry)
        start(coordinator)
        XCTAssertEqual(coordinator.update(.history, to: alternateHistory), .applied)
        XCTAssertEqual(coordinator.resetToDefaults(), .applied)
        let defaults = Set(NeClipShortcutAction.allCases.map(\.defaultShortcut))
        XCTAssertEqual(coordinator.allShortcuts, defaults)
        XCTAssertEqual(registry.active, defaults)
    }

    @MainActor
    func testFailedResetRestoresTheCompletePreviousWorkingSet() {
        let registry = FakeHotKeyRegistry()
        let coordinator = makeCoordinator(registry: registry)
        start(coordinator)
        XCTAssertEqual(coordinator.update(.history, to: alternateHistory), .applied)
        let previous = coordinator.allShortcuts
        registry.setBlocked([.historyDefault])

        guard case .rejected = coordinator.resetToDefaults() else {
            return XCTFail("Blocked default must reject reset")
        }
        XCTAssertEqual(coordinator.allShortcuts, previous)
        XCTAssertEqual(registry.active, previous)
    }

    @MainActor
    private func makeCoordinator(registry: FakeHotKeyRegistry) -> HotKeyCoordinator {
        HotKeyCoordinator(
            registrationFactory: registry,
            initialShortcuts: Dictionary(uniqueKeysWithValues: NeClipShortcutAction.allCases.map {
                ($0, $0.defaultShortcut)
            }),
            persistsSettings: false
        )
    }

    @MainActor
    private func start(_ coordinator: HotKeyCoordinator) {
        coordinator.start(
            historyAction: {},
            snippetsAction: {},
            sequentialPasteAction: {},
            manualCorrectionAction: {},
            disableAutomaticCorrectionAction: {}
        )
    }
}
