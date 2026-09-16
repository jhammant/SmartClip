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
    public var maxEntries: Int
    public var maxClipBytes: Int

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

    public init(dir: URL? = nil, maxEntries: Int = 1000, maxClipBytes: Int = 1_048_576) {
        self.dir = dir ?? HistoryStore.defaultDirectory()
        self.maxEntries = maxEntries
        self.maxClipBytes = maxClipBytes
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

    /// Drop the oldest entries past `maxEntries`, deleting their clip files.
    func prune() {
        guard let text = try? String(contentsOf: historyURL, encoding: .utf8) else { return }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard lines.count > maxEntries else { return }
        let dropped = lines.prefix(lines.count - maxEntries)
        for line in dropped {
            if let record = ClipRecord.parse(line), !record.file.isEmpty {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent(record.file))
            }
        }
        lines = Array(lines.suffix(maxEntries))
        try? (lines.joined(separator: "\n") + "\n").write(to: historyURL, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: historyURL.path)
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
        guard !record.file.isEmpty else { return nil }
        return try? String(contentsOf: dir.appendingPathComponent(record.file), encoding: .utf8)
    }

    public enum StoreError: Error {
        case cannotOpenHistory(Int32)
    }
}
