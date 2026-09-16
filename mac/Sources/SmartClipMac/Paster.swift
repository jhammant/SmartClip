import AppKit
import ApplicationServices
import SmartClipCore

/// What a clip actually is when it goes back on the clipboard.
enum ClipPayload {
    case text(String)
    case image(Data)
    case files([URL])
}

extension HistoryStore {
    /// Nil when the contents were evicted to stay under the disk budget — the
    /// history line survives for ever, the bytes may not.
    func payload(for record: ClipRecord) -> ClipPayload? {
        if record.isImage { return data(of: record).map(ClipPayload.image) }
        guard let content = content(of: record) else { return nil }
        if record.isFileList {
            let urls = content.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
            return urls.isEmpty ? nil : .files(urls)
        }
        return .text(content)
    }
}

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

    static func placeOnClipboard(_ payload: ClipPayload) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch payload {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let data):
            // Offer PNG and TIFF: some older apps only look for TIFF.
            pasteboard.setData(data, forType: NSPasteboard.PasteboardType("public.png"))
            if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        case .files(let urls):
            pasteboard.writeObjects(urls as [NSURL])
        }
    }

    /// Returns false when it could only put the clip on the clipboard.
    @discardableResult
    static func paste(_ payload: ClipPayload, into app: NSRunningApplication?) -> Bool {
        placeOnClipboard(payload)
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
