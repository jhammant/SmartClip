import AppKit
import SmartClipCore

/// Everything SmartClip does apart from its menu-bar icon: capture, the shared
/// history store, the ⌥⌘V picker and putting clips back. SmartClip.app hosts it,
/// and so can any other menu-bar app (Roost does), so there is one clipboard
/// engine whichever app is running it.
public final class SmartClipEngine {
    /// `SmartClip --show` posts this; whichever app is hosting the engine opens the picker.
    public static let showPickerNotification = Notification.Name("io.hammant.smartclip.showPicker")
    public static let smartClipBundleID = "io.hammant.smartclip"

    public let store: HistoryStore
    private lazy var watcher = ClipboardWatcher(store: store)
    private lazy var picker = PickerController(store: store)
    private var hotKey: HotKey?
    private var showObserver: NSObjectProtocol?

    public private(set) var isRunning = false

    public init(store: HistoryStore = HistoryStore()) {
        self.store = store
    }

    /// Starts capturing and registers ⌥⌘V. Returns false when another app owns ⌥⌘V.
    @discardableResult
    public func start() -> Bool {
        guard !isRunning else { return hotKeyRegistered }
        isRunning = true
        picker.willPaste = { [weak self] payload in self?.watcher.ignore(payload) }
        watcher.start()
        let hotKey = HotKey { [weak self] in self?.picker.toggle() }
        self.hotKey = hotKey
        showObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.showPickerNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.showPicker() }
        Log.debug("engine started; store at \(store.dir.path)")
        return hotKey.isRegistered
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        watcher.stop()
        hotKey = nil  // unregisters ⌥⌘V
        if let showObserver { DistributedNotificationCenter.default().removeObserver(showObserver) }
        showObserver = nil
        picker.hide()
    }

    public var hotKeyRegistered: Bool { hotKey?.isRegistered ?? false }

    public var isPaused: Bool {
        get { watcher.isPaused }
        set { watcher.isPaused = newValue }
    }

    public func showPicker() {
        // The menu is tracking when this fires from a click; let it close first
        // so the app we were in is still the one behind the picker.
        DispatchQueue.main.async { [weak self] in self?.picker.show() }
    }

    /// Clips that can still be pasted (their contents weren't evicted), newest first.
    public func recentClips(_ limit: Int = 8) -> [ClipRecord] {
        Array(store.recent(200).filter { store.fileURL(of: $0) != nil }.prefix(limit))
    }

    /// Puts a clip back on the clipboard without recording it again.
    /// False when its contents were evicted by the disk budget.
    @discardableResult
    public func copy(_ record: ClipRecord) -> Bool {
        guard let payload = store.payload(for: record) else { return false }
        watcher.ignore(payload)
        Paster.placeOnClipboard(payload)
        return true
    }

    public var hasAccessibility: Bool { Paster.hasAccessibility }

    public func requestAccessibility() {
        Paster.requestAccessibility()
    }

    /// The stand-alone SmartClip.app, if it is running: two engines would record every copy twice.
    public static func runningSmartClipApp() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: smartClipBundleID)
            .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    }
}
