import AppKit

/// A small floating toast. Deliberately not a system notification: those need a
/// bundle identifier registered with the notification centre and a permission
/// prompt, for something that only ever says "done".
enum Notifier {
    private static var panel: NSPanel?
    private static var hideWork: DispatchWorkItem?

    static func show(_ message: String, duration: TimeInterval = 2.2) {
        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .labelColor
        label.sizeToFit()

        let width = min(label.frame.width + 32, 520)
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setContentSize(NSSize(width: width, height: 40))

        if let background = panel.contentView as? NSVisualEffectView {
            background.subviews.forEach { $0.removeFromSuperview() }
            label.frame = NSRect(x: 16, y: 11, width: width - 32, height: 18)
            background.addSubview(label)
        }

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: frame.midX - width / 2, y: frame.minY + 90))
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideWork?.cancel()
        let work = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                panel.animator().alphaValue = 0
            } completionHandler: { panel.orderOut(nil) }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 40),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let background = NSVisualEffectView(frame: panel.contentLayoutRect)
        background.material = .hudWindow
        background.blendingMode = .behindWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 10
        background.layer?.masksToBounds = true
        background.autoresizingMask = [.width, .height]
        panel.contentView = background
        return panel
    }
}
