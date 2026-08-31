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

        deinit {
            registry?.release(shortcut)
        }
    }

    private let lock = NSLock()
    private var activeStorage: Set<ShortcutDescriptor> = []
    private var blockedStorage: Set<ShortcutDescriptor> = []

    var active: Set<ShortcutDescriptor> {
        lock.withLock { activeStorage }
    }

    func setBlocked(_ shortcuts: Set<ShortcutDescriptor>) {
        lock.withLock { blockedStorage = shortcuts }
    }

    func register(_ shortcut: ShortcutDescriptor) throws -> any HotKeyRegistrationToken {
        try lock.withLock {
            guard !blockedStorage.contains(shortcut), !activeStorage.contains(shortcut) else {
                throw GlobalHotKeyRegistrationError.alreadyRegistered(OSStatus(eventHotKeyExistsErr))
            }
            activeStorage.insert(shortcut)
            return Token(shortcut: shortcut, registry: self)
        }
    }

    func makeRegistration(
        shortcut: ShortcutDescriptor,
        identifier: UInt32,
        action: @escaping GlobalHotKey.Action
    ) throws -> any HotKeyRegistrationToken {
        try register(shortcut)
    }

    private func release(_ shortcut: ShortcutDescriptor) {
        _ = lock.withLock { activeStorage.remove(shortcut) }
    }
}

final class LayoutHotKeyCoordinatorTests: XCTestCase {
    private let alternateManual = ShortcutDescriptor(
        keyCode: UInt32(kVK_ANSI_M),
        modifiers: [.control, .shift]
    )

    @MainActor
    func testSameCandidateRetriesAfterStartupConflictDisappears() {
        let registry = FakeHotKeyRegistry()
        registry.setBlocked([.defaultManualLayout])
        let coordinator = makeCoordinator(registry: registry)
        coordinator.start(manualAction: {}, disableAction: {})
        XCTAssertFalse(registry.active.contains(.defaultManualLayout))

        registry.setBlocked([])
        XCTAssertEqual(coordinator.update(.manualCorrection, to: .defaultManualLayout), .applied)
        XCTAssertTrue(registry.active.contains(.defaultManualLayout))
    }

    @MainActor
    func testResetDefaultsHandlesAValidCrossAssignmentAsOnePair() {
        let registry = FakeHotKeyRegistry()
        let coordinator = makeCoordinator(registry: registry)
        coordinator.start(manualAction: {}, disableAction: {})

        XCTAssertEqual(coordinator.update(.manualCorrection, to: alternateManual), .applied)
        XCTAssertEqual(coordinator.update(.disableAutomaticCorrection, to: .defaultManualLayout), .applied)
        XCTAssertEqual(coordinator.resetToDefaults(), .applied)

        XCTAssertEqual(coordinator.manualShortcut, .defaultManualLayout)
        XCTAssertEqual(coordinator.disableAutomaticShortcut, .defaultDisableAutomaticLayout)
        XCTAssertEqual(registry.active, [.defaultManualLayout, .defaultDisableAutomaticLayout])
    }

    @MainActor
    func testFailedPairResetRestoresThePreviousWorkingPair() {
        let registry = FakeHotKeyRegistry()
        let coordinator = makeCoordinator(registry: registry)
        coordinator.start(manualAction: {}, disableAction: {})
        XCTAssertEqual(coordinator.update(.manualCorrection, to: alternateManual), .applied)

        registry.setBlocked([.defaultManualLayout])
        guard case .rejected = coordinator.resetToDefaults() else {
            return XCTFail("Blocked default must reject the pair reset")
        }

        XCTAssertEqual(coordinator.manualShortcut, alternateManual)
        XCTAssertEqual(coordinator.disableAutomaticShortcut, .defaultDisableAutomaticLayout)
        XCTAssertEqual(registry.active, [alternateManual, .defaultDisableAutomaticLayout])
    }

    @MainActor
    private func makeCoordinator(registry: FakeHotKeyRegistry) -> LayoutHotKeyCoordinator {
        LayoutHotKeyCoordinator(
            registrationFactory: registry,
            initialManualShortcut: .defaultManualLayout,
            initialDisableAutomaticShortcut: .defaultDisableAutomaticLayout,
            persistsSettings: false
        )
    }
}
