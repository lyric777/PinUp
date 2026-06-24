import Carbon
import Foundation

@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var actions: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?

    private init() {}

    func register(identifier: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        actions[identifier] = action
        installEventHandlerIfNeeded()

        if let existingRef = hotKeyRefs[identifier] {
            UnregisterEventHotKey(existingRef)
            hotKeyRefs.removeValue(forKey: identifier)
        }

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("Pinu"), id: identifier)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)

        if let hotKeyRef {
            hotKeyRefs[identifier] = hotKeyRef
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else {
            return
        }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, _ in
                guard let eventRef else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else {
                    return status
                }

                Task { @MainActor in
                    HotkeyManager.shared.handleHotKeyPress(id: hotKeyID.id)
                }
                return noErr
            },
            1,
            &eventSpec,
            nil,
            &eventHandler
        )
    }

    private func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }

    private func handleHotKeyPress(id: UInt32) {
        actions[id]?()
    }
}
