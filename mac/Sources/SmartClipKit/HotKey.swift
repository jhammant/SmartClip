import AppKit
import Carbon.HIToolbox

/// A system-wide hotkey via Carbon's `RegisterEventHotKey`. It is the old API,
/// but it is the only one that works without Accessibility permission — the
/// modern alternative is an event tap, which needs that grant just to listen.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let action: () -> Void

    /// False when another app already owns the combination — otherwise the
    /// hotkey just silently never fires.
    private(set) var isRegistered = false

    /// ⌥⌘V by default.
    init(keyCode: UInt32 = UInt32(kVK_ANSI_V),
         modifiers: UInt32 = UInt32(cmdKey | optionKey),
         action: @escaping () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().action()
            return noErr
        }, 1, &eventType, context, &eventHandler)

        let id = EventHotKeyID(signature: OSType(0x53434C50), id: 1) // 'SCLP'
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        isRegistered = status == noErr
        Log.debug(isRegistered ? "hotkey registered" : "hotkey NOT registered (OSStatus \(status))")
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }
}
