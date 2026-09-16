import Foundation

/// Reads and writes the same store the `smartclip` CLI uses:
///
///     ~/.local/share/smartclip/history.jsonl   one JSON object per copy
///     ~/.local/share/smartclip/clips/N.txt     the content of copy N
///     ~/.local/share/smartclip/.seq            the counter for N
///
/// Sharing the store is the whole point — `/clh` recall and `/pst` see what you
/// copied yourself, not just what Claude copied for you.
public final class HistoryStore {
    public let dir: URL
    /// 0 = keep every history line for ever. The index is the archive: ~200
    /// bytes per clip, so a decade of copying is a few hundred MB.
    public var maxEntries: Int
    public var maxClipBytes: Int
    /// Images get their own, much larger limit — a screenshot is routinely
    /// several MB, and refusing it would make image capture pointless.
    public var maxBinaryBytes: Int
    /// How much disk the stored clip *contents* may use. When it is exceeded
    /// the oldest contents are deleted, oldest first; their history lines stay,
    /// so you can still see what you copied, just not get it back.
    public var budgetBytes: Int

    private var storedBytesCache: Int?

    private let historyURL: URL
    private let clipsDir: URL
    private let seqURL: URL
    private let queue = DispatchQueue(label: "io.hammant.smartclip.store")

    public static func defaultDirectory() -> URL {
        let env = ProcessInfo.processInfo.environment
        if let explicit = env["SMARTCLIP_DATA_DIR"], !explicit.isEmpty {
            return URL(fileURLWithPath: (explicit as NSString).expandingTildeInPath)
        }
        let base = env["XDG_DATA_HOME"].flatMap { $0.isEmpty ? nil : $0 }
            ?? (NSHomeDirectory() + "/.local/share")
        return URL(fileURLWithPath: base).appendingPathComponent("smartclip")
    }

    /// Overridable from the environment, so the app and the CLI agree:
    ///   SMARTCLIP_BUDGET_GB       total disk for clip contents   (default 20)
    ///   SMARTCLIP_MAX_CLIP_MB     largest single image to keep   (default 16)
    ///   SMARTCLIP_HISTORY_MAXSIZE largest single text clip       (default 1 MiB)
    ///   SMARTCLIP_HISTORY_MAX     line cap, 0 = keep for ever    (default 0)
    public init(dir: URL? = nil, maxEntries: Int? = nil, maxClipBytes: Int? = nil,
                maxBinaryBytes: Int? = nil, budgetBytes: Int? = nil) {
        let env = ProcessInfo.processInfo.environment
        func number(_ key: String) -> Int? { env[key].flatMap { Int($0) } }
        func decimal(_ key: String) -> Double? { env[key].flatMap { Double($0) } }

        self.dir = dir ?? HistoryStore.defaultDirectory()
        self.maxEntries = maxEntries ?? number("SMARTCLIP_HISTORY_MAX") ?? 0
        self.maxClipBytes = maxClipBytes ?? number("SMARTCLIP_HISTORY_MAXSIZE") ?? 1_048_576
        self.maxBinaryBytes = maxBinaryBytes
            ?? decimal("SMARTCLIP_MAX_CLIP_MB").map { Int($0 * 1_048_576) } ?? 16_777_216
        self.budgetBytes = budgetBytes
            ?? decimal("SMARTCLIP_BUDGET_GB").map { Int($0 * 1_073_741_824) } ?? 21_474_836_480
        historyURL = self.dir.appendingPathComponent("history.jsonl")
        clipsDir = self.dir.appendingPathComponent("clips")
        seqURL = self.dir.appendingPathComponent(".seq")
    }

    // MARK: - Writing

    /// Records one copy. Secrets and oversized clips are logged but their
    /// content is never written to disk, exactly as the CLI does it.
    @discardableResult
    public func append(content: String, type: String? = nil, label: String = "",
                       app: String = "") throws -> ClipRecord {
        try queue.sync {
            try ensureDirectories()
            let bytes = content.utf8.count
            var record: ClipRecord

            if bytes > maxClipBytes {
                record = ClipRecord(ts: ClipRecord.timestamp(), type: "large",
                                    label: "(skipped: \(bytes) bytes, over \(maxClipBytes)B limit)",
                                    bytes: bytes, app: app, preview: "(not stored)")
            } else if SecretFilter.looksSecret(content) {
                record = ClipRecord(ts: ClipRecord.timestamp(), type: "redacted",
                                    label: "(skipped: looked like a secret)",
                                    bytes: bytes, app: app, preview: "(redacted)")
            } else {
                let seq = try nextSequence()
                let relative = "clips/\(seq).txt"
                let url = dir.appendingPathComponent(relative)
                try content.write(to: url, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                                     ofItemAtPath: url.path)
                if let cached = storedBytesCache { storedBytesCache = cached + bytes }
                record = ClipRecord(ts: ClipRecord.timestamp(),
                                    type: type ?? TypeGuess.of(content),
                                    label: label, bytes: bytes, file: relative, app: app,
                                    preview: ClipRecord.makePreview(content))
            }

            try appendLine(record.jsonLine)
            prune()
            return record
        }
    }

    /// Records a non-text clip — an image, for now. The bytes go to
    /// `clips/N.<ext>` and the history line carries a human summary, so the
    /// shell helper's `history list` still reads sensibly.
    @discardableResult
    public func append(data: Data, fileExtension: String, type: String, preview: String,
                       label: String = "", app: String = "") throws -> ClipRecord {
        try queue.sync {
            try ensureDirectories()
            var record: ClipRecord

            if data.count > maxBinaryBytes {
                record = ClipRecord(ts: ClipRecord.timestamp(), type: "large",
                                    label: "(skipped: \(data.count) bytes, over \(maxBinaryBytes)B limit)",
                                    bytes: data.count, app: app, preview: "(not stored)")
            } else {
                let seq = try nextSequence()
                let relative = "clips/\(seq).\(fileExtension)"
                let url = dir.appendingPathComponent(relative)
                try data.write(to: url, options: .atomic)
                try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                                     ofItemAtPath: url.path)
                if let cached = storedBytesCache { storedBytesCache = cached + data.count }
                record = ClipRecord(ts: ClipRecord.timestamp(), type: type, label: label,
                                    bytes: data.count, file: relative, app: app, preview: preview)
            }

            try appendLine(record.jsonLine)
            prune()
            return record
        }
    }

    private func ensureDirectories() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: clipsDir.path) {
            try fm.createDirectory(at: clipsDir, withIntermediateDirectories: true,
                                   attributes: [.posixPermissions: 0o700])
        }
        try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
    }

    /// O_APPEND write of a whole line, so a copy made in the terminal and a copy
    /// made in the UI at the same moment cannot interleave.
    private func appendLine(_ line: String) throws {
        let fd = open(historyURL.path, O_WRONLY | O_APPEND | O_CREAT, 0o600)
        guard fd >= 0 else { throw StoreError.cannotOpenHistory(errno) }
        defer { close(fd) }
        let data = Array((line + "\n").utf8)
        var offset = 0
        while offset < data.count {
            let written = data.withUnsafeBytes { buf -> Int in
                write(fd, buf.baseAddress!.advanced(by: offset), data.count - offset)
            }
            if written <= 0 { throw StoreError.cannotOpenHistory(errno) }
            offset += written
        }
    }

    private func nextSequence() throws -> Int {
        let current = (try? String(contentsOf: seqURL, encoding: .utf8))
            .flatMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
        let next = current + 1
        try String(next).write(to: seqURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: seqURL.path)
        return next
    }

    func prune() {
        if maxEntries > 0 { dropOldestLines() }
        enforceBudget()
    }

    /// Only used when someone asks for a line cap; by default the index is kept
    /// for ever and only the contents are evicted.
    private func dropOldestLines() {
        guard let text = try? String(contentsOf: historyURL, encoding: .utf8) else { return }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count > maxEntries else { return }
        for line in lines.prefix(lines.count - maxEntries) {
            if let record = ClipRecord.parse(line), !record.file.isEmpty {
                remove(dir.appendingPathComponent(record.file))
            }
        }
        lines = Array(lines.suffix(maxEntries))
        try? (lines.joined(separator: "\n") + "\n").write(to: historyURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: historyURL.path)
    }

    /// Delete the oldest stored contents until we are back under budget, with a
    /// little headroom so this doesn't run on every single copy.
    private func enforceBudget() {
        guard storedBytes() > budgetBytes else { return }
        let target = Int(Double(budgetBytes) * 0.95)
        guard let text = try? String(contentsOf: historyURL, encoding: .utf8) else { return }
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard storedBytes() > target else { break }
            guard let record = ClipRecord.parse(String(line)), !record.file.isEmpty else { continue }
            remove(dir.appendingPathComponent(record.file))
        }
    }

    private func remove(_ url: URL) {
        let size = fileSize(url)
        guard (try? FileManager.default.removeItem(at: url)) != nil else { return }
        if let size, let cached = storedBytesCache { storedBytesCache = max(0, cached - size) }
    }

    private func fileSize(_ url: URL) -> Int? {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
    }

    /// How much disk the stored clip contents currently take. Counted once,
    /// then tracked as clips are added and evicted.
    public func storedBytes() -> Int {
        if let cached = storedBytesCache { return cached }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: clipsDir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let total = urls.reduce(0) { $0 + (fileSize($1) ?? 0) }
        storedBytesCache = total
        return total
    }

    // MARK: - Reading

    /// Newest first.
    public func recent(_ limit: Int = 200) -> [ClipRecord] {
        guard let text = try? String(contentsOf: historyURL, encoding: .utf8) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: true)
            .suffix(limit)
            .reversed()
            .compactMap { ClipRecord.parse(String($0)) }
    }

    public func last() -> ClipRecord? { recent(1).first }

    public func content(of record: ClipRecord) -> String? {
        guard !record.file.isEmpty, record.file.hasSuffix(".txt") else { return nil }
        return try? String(contentsOf: dir.appendingPathComponent(record.file), encoding: .utf8)
    }

    /// Where the clip's bytes live, text or otherwise.
    public func fileURL(of record: ClipRecord) -> URL? {
        guard !record.file.isEmpty else { return nil }
        let url = dir.appendingPathComponent(record.file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    public func data(of record: ClipRecord) -> Data? {
        fileURL(of: record).flatMap { try? Data(contentsOf: $0) }
    }

    public enum StoreError: Error {
        case cannotOpenHistory(Int32)
    }
}
