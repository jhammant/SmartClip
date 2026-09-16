import AppKit
import ServiceManagement
import SmartClipCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let showPickerNotification = Notification.Name("io.hammant.smartclip.showPicker")

    private let store = HistoryStore()
    private lazy var watcher = ClipboardWatcher(store: store)
    private lazy var picker = PickerController(store: store)
    private var statusItem: NSStatusItem!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()

        picker.willPaste = { [weak self] payload in self?.watcher.ignore(payload) }
        watcher.start()
        let hotKey = HotKey { [weak self] in self?.picker.toggle() }
        self.hotKey = hotKey
        if !hotKey.isRegistered {
            Notifier.show("⌥⌘V is taken by another app — use the menu bar icon to search clips")
        }

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(showPicker),
            name: Self.showPickerNotification, object: nil)
        Log.debug("launched; store at \(store.dir.path)")
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

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let recent = store.recent(200).filter { store.fileURL(of: $0) != nil }.prefix(8)
        if recent.isEmpty {
            menu.addItem(withTitle: "Nothing copied yet", action: nil, keyEquivalent: "")
        } else {
            menu.addItem(withTitle: "Recent clips", action: nil, keyEquivalent: "")
            for (index, record) in recent.enumerated() {
                let title = String(record.displayText.prefix(60))
                let item = NSMenuItem(title: title, action: #selector(copyRecent(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                item.toolTip = record.app.isEmpty ? record.type : "\(record.app) · \(record.type)"
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let used = ByteCountFormatter.string(fromByteCount: Int64(store.storedBytes()), countStyle: .file)
        let budget = ByteCountFormatter.string(fromByteCount: Int64(store.budgetBytes), countStyle: .file)
        menu.addItem(withTitle: "Archive: \(used) of \(budget)", action: nil, keyEquivalent: "")

        add(to: menu, "Search clips…  ⌥⌘V", #selector(showPicker))
        add(to: menu, watcher.isPaused ? "Resume capture" : "Pause capture", #selector(togglePause))
        if !Paster.hasAccessibility {
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
        // The menu is tracking when this fires from a click; let it close first
        // so the app we were in is still the one behind the picker.
        DispatchQueue.main.async { [weak self] in self?.picker.show() }
    }

    @objc private func copyRecent(_ sender: NSMenuItem) {
        let recent = store.recent(200).filter { store.fileURL(of: $0) != nil }
        guard recent.indices.contains(sender.tag),
              let payload = store.payload(for: recent[sender.tag]) else { return }
        watcher.ignore(payload)
        Paster.placeOnClipboard(payload)
        Notifier.show("Copied — press ⌘V where you want it")
    }

    @objc private func togglePause() {
        watcher.isPaused.toggle()
        Notifier.show(watcher.isPaused ? "Clipboard capture paused" : "Clipboard capture on")
    }

    @objc private func requestAccessibility() {
        Paster.requestAccessibility()
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
        NSWorkspace.shared.open(store.dir)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
