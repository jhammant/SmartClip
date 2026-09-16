import Foundation

/// One line of `history.jsonl`.
///
/// The shell helper (`bin/smartclip`) parses this file with `sed`, one field at
/// a time, so the field order and escaping here must match what it writes:
/// ts, dir, type, label, bytes, file, [app], preview — preview stays last,
/// because its value is the only one that can contain arbitrary text.
public struct ClipRecord: Equatable {
    public var ts: String
    public var dir: String
    public var type: String
    public var label: String
    public var bytes: Int
    /// Relative path of the stored clip ("clips/42.txt"), or "" when not stored.
    public var file: String
    /// Source application. Empty for entries written by the shell helper.
    public var app: String
    public var preview: String

    public init(ts: String, dir: String = "copy", type: String, label: String = "",
                bytes: Int, file: String = "", app: String = "", preview: String) {
        self.ts = ts
        self.dir = dir
        self.type = type
        self.label = label
        self.bytes = bytes
        self.file = file
        self.app = app
        self.preview = preview
    }

    public var jsonLine: String {
        let fields = [
            "\"ts\":\"\(Self.escape(ts))\"",
            "\"dir\":\"\(Self.escape(dir))\"",
            "\"type\":\"\(Self.escape(type))\"",
            "\"label\":\"\(Self.escape(label))\"",
            "\"bytes\":\(bytes)",
            "\"file\":\"\(Self.escape(file))\"",
            "\"app\":\"\(Self.escape(app))\"",
            "\"preview\":\"\(Self.escape(preview))\"",
        ]
        return "{" + fields.joined(separator: ",") + "}"
    }

    /// Mirrors the helper's `ejson`: escape backslash and quote, drop control
    /// characters entirely (rather than emitting \u escapes) so the sed field
    /// extraction on the other side stays simple.
    static func escape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            default:
                if scalar.value >= 0x20 && scalar.value != 0x7F { out.unicodeScalars.append(scalar) }
            }
        }
        return out
    }

    /// Mirrors the helper's `make_preview`: first 140 bytes, on one line.
    public static func makePreview(_ content: String) -> String {
        let flattened = content.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let bytes = Array(flattened.utf8.prefix(140))
        return String(decoding: bytes, as: UTF8.self)
    }

    public static func parse(_ line: String) -> ClipRecord? {
        guard let data = line.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        func str(_ key: String) -> String { obj[key] as? String ?? "" }
        return ClipRecord(
            ts: str("ts"),
            dir: str("dir"),
            type: str("type"),
            label: str("label"),
            bytes: obj["bytes"] as? Int ?? 0,
            file: str("file"),
            app: str("app"),
            preview: str("preview")
        )
    }

    public static func timestamp(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.string(from: date)
    }

    public var date: Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: ts)
    }

    /// What the picker shows: the human label when Claude gave it one,
    /// otherwise the preview of the content itself.
    public var displayText: String { label.isEmpty ? preview : label }

    public var isImage: Bool { type == "image" }
    /// A copy of one or more files from the Finder: the stored text is their paths.
    public var isFileList: Bool { type == "files" }
}
