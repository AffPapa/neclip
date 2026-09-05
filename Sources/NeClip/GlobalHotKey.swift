import Carbon.HIToolbox
import Foundation

enum GlobalHotKeyRegistrationError: Error, Equatable, Sendable {
    case eventHandlerInstallationFailed(OSStatus)
    case alreadyRegistered(OSStatus)
    case registrationFailed(OSStatus)
    case missingRegistrationReference
}

protocol HotKeyRegistrationToken: AnyObject {}

protocol HotKeyRegistrationCreating {
    func makeRegistration(
        shortcut: ShortcutDescriptor,
        identifier: UInt32,
        action: @escaping GlobalHotKey.Action
    ) throws -> any HotKeyRegistrationToken
}

struct CarbonHotKeyRegistrationFactory: HotKeyRegistrationCreating {
    func makeRegistration(
        shortcut: ShortcutDescriptor,
        identifier: UInt32,
        action: @escaping GlobalHotKey.Action
    ) throws -> any HotKeyRegistrationToken {
        try GlobalHotKey(shortcut: shortcut, identifier: identifier, action: action)
    }
}

/// A minimal Carbon wrapper for the global shortcuts NeClip owns.
/// Carbon still provides the native macOS registration API and avoids a
/// separate package for this small, stable surface.
final class GlobalHotKey: @unchecked Sendable {
    typealias Action = @Sendable () -> Void

    private let identifier: UInt32
    private let action: Action
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(shortcut: ShortcutDescriptor, identifier: UInt32, action: @escaping Action) throws {
        self.identifier = identifier
        self.action = action

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            neClipGlobalHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            eventHandler = nil
            throw GlobalHotKeyRegistrationError.eventHandlerInstallationFailed(handlerStatus)
        }

        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let registrationStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &reference
        )
        guard registrationStatus == noErr else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            eventHandler = nil
            if registrationStatus == OSStatus(eventHotKeyExistsErr) {
                throw GlobalHotKeyRegistrationError.alreadyRegistered(registrationStatus)
            }
            throw GlobalHotKeyRegistrationError.registrationFailed(registrationStatus)
        }
        guard let reference else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            eventHandler = nil
            throw GlobalHotKeyRegistrationError.missingRegistrationReference
        }
        hotKey = reference
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    fileprivate func handle(event: EventRef) -> OSStatus {
        var received = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &received
        )
        guard status == noErr else { return OSStatus(eventNotHandledErr) }
        return Self.dispatch(
            eventKind: GetEventKind(event),
            received: received,
            identifier: identifier,
            action: action
        )
    }

    /// Finish consuming our Carbon event before an action can enter AppKit's
    /// nested menu tracking loop. Unrelated keys and releases remain unhandled.
    @discardableResult
    static func dispatch(
        eventKind: UInt32,
        received: EventHotKeyID,
        identifier: UInt32,
        action: @escaping Action
    ) -> OSStatus {
        guard eventKind == UInt32(kEventHotKeyPressed),
              received.signature == signature,
              received.id == identifier else { return OSStatus(eventNotHandledErr) }
        DispatchQueue.main.async(execute: action)
        return noErr
    }

    static let signature: OSType = 0x4E_43_4C_50 // "NCLP"
}

extension GlobalHotKey: HotKeyRegistrationToken {}

private let neClipGlobalHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    return Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().handle(event: event)
}
