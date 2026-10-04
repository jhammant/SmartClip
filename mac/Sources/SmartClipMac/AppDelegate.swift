import AppKit
import ServiceManagement
import SmartClipCore
import SmartClipKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = SmartClipEngine()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()
        if !engine.start() {
            Notifier.show("⌥⌘V is taken by another app — use the menu bar icon to search clips")
        }
        Log.debug("launched; store at \(engine.store.dir.path)")
    }

    // MARK: - Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "list.clipboard",
                                           accessibilityDescription: "SmartClip")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private var shownClips: [ClipRecord] = []

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        shownClips = engine.recentClips(8)
        if shownClips.isEmpty {
            menu.addItem(withTitle: "Nothing copied yet", action: nil, keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Recent clips", action: nil, keyEquivalent: "")
            for (index, record) in shownClips.enumerated() {
                let title = String(record.displayText.prefix(60))
                let item = NSMenuItem(title: title, action: #selector(copyRecent(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                item.toolTip = record.app.isEmpty ? record.type : "\(record.app) · \(record.type)"
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let store = engine.store
        let used = ByteCountFormatter.string(fromByteCount: Int64(store.storedBytes()), countStyle: .file)
        let budget = ByteCountFormatter.string(fromByteCount: Int64(store.budgetBytes), countStyle: .file)
        menu.addItem(withTitle: "Archive: \(used) of \(budget)", action: nil, keyEquivalent: "")

        add(to: menu, "Search clips…  ⌥⌘V", #selector(showPicker))
        add(to: menu, engine.isPaused ? "Resume capture" : "Pause capture", #selector(togglePause))
        if !engine.hasAccessibility {
            add(to: menu, "Enable paste-back…", #selector(requestAccessibility))
        }
        add(to: menu, "Open history folder", #selector(openHistoryFolder))
        let loginItem = NSMenuItem(title: "Open at login", action: #selector(toggleOpenAtLogin), keyEquivalent: "")
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        menu.addItem(.separator())
        add(to: menu, "Quit SmartClip", #selector(quit))
    }

    private func add(to menu: NSMenu, _ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func showPicker() {
        Log.debug("showPicker requested")
        engine.showPicker()
    }

    @objc private func copyRecent(_ sender: NSMenuItem) {
        guard shownClips.indices.contains(sender.tag), engine.copy(shownClips[sender.tag]) else { return }
        Notifier.show("Copied — press ⌘V where you want it")
    }

    @objc private func togglePause() {
        engine.isPaused.toggle()
        Notifier.show(engine.isPaused ? "Clipboard capture paused" : "Clipboard capture on")
    }

    @objc private func requestAccessibility() {
        engine.requestAccessibility()
    }

    /// SMAppService registers the bundle itself as a login item — no helper
    /// tool, no LaunchAgent plist, and the user can revoke it in
    /// System Settings › General › Login Items.
    @objc private func toggleOpenAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                Notifier.show("SmartClip will not start at login")
            } else {
                try SMAppService.mainApp.register()
                Notifier.show("SmartClip will start at login")
            }
        } catch {
            Notifier.show("Could not change login item: \(error.localizedDescription)")
        }
    }

    @objc private func openHistoryFolder() {
        NSWorkspace.shared.open(engine.store.dir)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
