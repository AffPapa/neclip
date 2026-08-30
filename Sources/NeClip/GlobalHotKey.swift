import Carbon.HIToolbox
import Foundation

/// A minimal Carbon wrapper for the three global shortcuts NeClip owns.
/// Carbon still provides the native macOS registration API and avoids a
/// separate package for this small, stable surface.
final class GlobalHotKey: @unchecked Sendable {
    typealias Action = @Sendable () -> Void

    private let identifier: UInt32
    private let action: Action
    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init?(keyCode: UInt32, modifiers: UInt32, identifier: UInt32, action: @escaping Action) {
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
        guard handlerStatus == noErr else { return nil }

        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: identifier)
        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard registrationStatus == noErr, let reference else {
            if let eventHandler { RemoveEventHandler(eventHandler) }
            eventHandler = nil
            return nil
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
        guard status == noErr,
              received.signature == Self.signature,
              received.id == identifier else { return OSStatus(eventNotHandledErr) }
        action()
        return noErr
    }

    private static let signature: OSType = 0x4E_43_4C_50 // "NCLP"
}

private let neClipGlobalHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    return Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().handle(event: event)
}
