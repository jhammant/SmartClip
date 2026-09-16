import AppKit
import ApplicationServices

/// Puts a clip back on the clipboard and, when allowed, presses ⌘V for you.
enum Paster {
    /// Synthesising a keystroke needs Accessibility. macOS ties that grant to
    /// the app's code signature, which is why the build script signs every
    /// build with the same Developer identity — an ad-hoc signature changes on
    /// each rebuild and the permission would have to be granted again.
    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func requestAccessibility() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func placeOnClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Returns false when it could only put the text on the clipboard.
    @discardableResult
    static func paste(_ text: String, into app: NSRunningApplication?) -> Bool {
        placeOnClipboard(text)
        guard hasAccessibility else { return false }

        app?.activate()
        let delay: TimeInterval = app == nil ? 0.05 : 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { sendCommandV() }
        return true
    }

    private static func sendCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let v: CGKeyCode = 0x09
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: v, keyDown: false)
        else { return }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
