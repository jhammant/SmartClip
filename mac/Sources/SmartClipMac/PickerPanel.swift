import AppKit
import SmartClipCore

/// The ⌥⌘V window: type to narrow, ↑/↓ to choose, ⏎ to paste, ⌘1–9 for the
/// top items, ⎋ to dismiss.
final class PickerController: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let store: HistoryStore
    private let panel: NSPanel
    private let searchField = NSTextField()
    private let tableView = NSTableView()
    private let footer = NSTextField(labelWithString: "")

    private var records: [ClipRecord] = []
    private var filtered: [ClipRecord] = []
    private var previousApp: NSRunningApplication?
    private var keyMonitor: Any?

    /// Lets the watcher know we are about to write to the clipboard ourselves.
    var willPaste: ((String) -> Void)?

    init(store: HistoryStore) {
        self.store = store
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
                        styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        super.init()
        buildUI()
    }

    var isVisible: Bool { panel.isVisible }

    // MARK: - UI

    private func buildUI() {
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.animationBehavior = .utilityWindow
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            panel.standardWindowButton(button)?.isHidden = true
        }

        let background = NSVisualEffectView(frame: panel.contentLayoutRect)
        // .menu is close to opaque: the picker opens over whatever you were
        // reading, and a translucent list of clips is unreadable there.
        background.material = .menu
        background.blendingMode = .behindWindow
        background.state = .active
        background.autoresizingMask = [.width, .height]
        panel.contentView = background

        searchField.frame = NSRect(x: 16, y: background.bounds.height - 46, width: background.bounds.width - 32, height: 30)
        searchField.autoresizingMask = [.width, .minYMargin]
        searchField.placeholderString = "Search your clipboard history…"
        searchField.font = .systemFont(ofSize: 15)
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.delegate = self
        background.addSubview(searchField)

        let separator = NSBox(frame: NSRect(x: 0, y: background.bounds.height - 54, width: background.bounds.width, height: 1))
        separator.boxType = .separator
        separator.autoresizingMask = [.width, .minYMargin]
        background.addSubview(separator)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("clip"))
        column.width = background.bounds.width - 24
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 48
        tableView.backgroundColor = .clear
        tableView.style = .inset
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(pasteDoubleClicked)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 28, width: background.bounds.width,
                                                   height: background.bounds.height - 82))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.documentView = tableView
        background.addSubview(scrollView)

        footer.frame = NSRect(x: 16, y: 6, width: background.bounds.width - 32, height: 18)
        footer.autoresizingMask = [.width, .maxYMargin]
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .tertiaryLabelColor
        footer.stringValue = "⏎ paste · ⌘1–9 quick paste · ⎋ close"
        background.addSubview(footer)
    }

    // MARK: - Showing

    func toggle() { isVisible ? hide() : show() }

    func show() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier { previousApp = frontmost }

        records = store.recent(500).filter { !$0.file.isEmpty }
        searchField.stringValue = ""
        applyFilter()

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2,
                                         y: frame.midY - size.height / 2 + 80))
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
        installKeyMonitor()
        Log.debug("picker shown: \(records.count) clips, visible=\(panel.isVisible), frame=\(panel.frame)")
    }

    func hide() {
        removeKeyMonitor()
        panel.orderOut(nil)
        previousApp?.activate()
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            if event.modifierFlags.contains(.command),
               let digit = event.charactersIgnoringModifiers.flatMap({ Int($0) }),
               (1...9).contains(digit) {
                self.paste(at: digit - 1)
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    // MARK: - Filtering

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        if query.isEmpty {
            filtered = records
        } else {
            let terms = query.split(separator: " ").map(String.init)
            filtered = records.filter { record in
                let haystack = "\(record.displayText) \(record.preview) \(record.app) \(record.type)".lowercased()
                return terms.allSatisfy { haystack.contains($0) }
            }
        }
        tableView.reloadData()
        if !filtered.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    // MARK: - Pasting

    @objc private func pasteDoubleClicked() { paste(at: tableView.selectedRow) }

    private func paste(at index: Int) {
        guard filtered.indices.contains(index),
              let content = store.content(of: filtered[index])
        else { return }
        willPaste?(content)
        hide()
        let pasted = Paster.paste(content, into: previousApp)
        if !pasted { Notifier.show("Copied to clipboard — press ⌘V to paste (Accessibility not granted)") }
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("cell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? ClipCellView
            ?? ClipCellView(identifier: identifier)
        cell.configure(with: filtered[row], shortcut: row < 9 ? row + 1 : nil)
        return cell
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            move(by: 1); return true
        case #selector(NSResponder.moveUp(_:)):
            move(by: -1); return true
        case #selector(NSResponder.insertNewline(_:)):
            paste(at: tableView.selectedRow); return true
        case #selector(NSResponder.cancelOperation(_:)):
            hide(); return true
        default:
            return false
        }
    }

    func controlTextDidChange(_ obj: Notification) { applyFilter() }

    private func move(by delta: Int) {
        guard !filtered.isEmpty else { return }
        let next = min(max(tableView.selectedRow + delta, 0), filtered.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }
}

/// Two lines: the clip, then where it came from and when.
private final class ClipCellView: NSTableCellView {
    private let title = NSTextField(labelWithString: "")
    private let subtitle = NSTextField(labelWithString: "")

    init(identifier: NSUserInterfaceItemIdentifier) {
        super.init(frame: .zero)
        self.identifier = identifier
        title.font = .systemFont(ofSize: 13)
        title.lineBreakMode = .byTruncatingTail
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [title, subtitle])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func configure(with record: ClipRecord, shortcut: Int?) {
        let prefix = shortcut.map { "⌘\($0)  " } ?? ""
        title.stringValue = prefix + record.displayText
        // No source app means the shell helper wrote it — that is /cpy.
        var parts = [record.app.isEmpty ? "Claude" : record.app, record.type]
        if let date = record.date { parts.append(Self.relative(date)) }
        subtitle.stringValue = parts.joined(separator: " · ")
    }

    private static func relative(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(seconds / 60)m ago"
        case ..<86_400: return "\(seconds / 3600)h ago"
        default: return "\(seconds / 86_400)d ago"
        }
    }
}
