import AppKit
import Carbon.HIToolbox

nonisolated private func moHotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let monitor = Unmanaged<GlobalHotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        monitor.handleHotkeyEvent()
    }
    return noErr
}

@MainActor
final class GlobalHotkeyMonitor {
    var onHotkey: (() -> Void)?

    private var eventHandler: EventHandlerRef?
    private var hotkeyRef: EventHotKeyRef?
    private(set) var registrationError: String?

    private let signature: OSType = 0x4D6F486B // "MoHk"
    private let identifier: UInt32 = 1

    func start(hotkey: Hotkey) {
        stop()
        registrationError = nil

        guard !hotkey.isReservedBySystem else {
            registrationError = "⌘, is reserved for the active app's Settings command."
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            moHotkeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            registrationError = "Could not install the shortcut handler (\(handlerStatus))."
            return
        }

        let hotkeyID = EventHotKeyID(signature: signature, id: identifier)
        let registerStatus = RegisterEventHotKey(
            UInt32(hotkey.keyCode),
            carbonModifiers(from: hotkey.modifierFlags),
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
        if registerStatus != noErr {
            registrationError = "That shortcut is unavailable (\(registerStatus))."
            if let eventHandler {
                RemoveEventHandler(eventHandler)
                self.eventHandler = nil
            }
        }
    }

    func stop() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    func handleHotkeyEvent() {
        onHotkey?()
    }

    private func carbonModifiers(from rawValue: UInt) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: rawValue)
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
