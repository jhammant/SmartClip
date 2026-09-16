import Foundation

/// Best-effort "don't store this" check, ported from `looks_secret` in the
/// shell helper so the app and the CLI refuse exactly the same things.
public enum SecretFilter {
    private static let tokenShapes = [
        "(ghp_|gho_|ghu_|ghs_|github_pat_|glpat-)",
        "sk-[A-Za-z0-9]{8}",
        "(sk_live_|rk_live_)",
        "(xox[baprs]-|xapp-)",
        "(AKIA|ASIA)[0-9A-Z]{12}",
        "AIza[0-9A-Za-z_-]{20}",
        "ya29\\.",
        "eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]+",
        "-----BEGIN [A-Z ]*PRIVATE KEY-----",
    ]

    private static let assignment =
        "(?i)(password|passwd|secret|api[_-]?key|access[_-]?token|auth[_-]?token|private[_-]?key|client[_-]?secret)[ \\t]*[:=][ \\t]*[^ \\t\\r\\n]"

    /// `SMARTCLIP_HISTORY_EXCLUDE` — the user's own never-store regex.
    public static var userExclusion: String? = ProcessInfo.processInfo.environment["SMARTCLIP_HISTORY_EXCLUDE"]

    public static func looksSecret(_ content: String) -> Bool {
        if let extra = userExclusion, !extra.isEmpty, matches(extra, content) { return true }
        for pattern in tokenShapes where matches(pattern, content) { return true }
        if matches(assignment, content) { return true }
        return isLoneOpaqueToken(content)
    }

    /// A single line that is one long opaque blob is almost always a key —
    /// unless it is a filesystem path, which is long, slash-heavy and
    /// completely ordinary to copy.
    private static func isLoneOpaqueToken(_ content: String) -> Bool {
        let lines = content.split(whereSeparator: \.isNewline)
        guard lines.count <= 1 else { return false }
        let token = content.filter { !$0.isWhitespace }
        guard token.utf8.count >= 40, !token.contains("://"), !isPath(token) else { return false }
        return matches("^[A-Za-z0-9+/_=.-]+$", token)
    }

    private static func isPath(_ token: String) -> Bool {
        ["/", "~/", "./", "../"].contains { token.hasPrefix($0) }
    }

    private static func matches(_ pattern: String, _ s: String) -> Bool {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return false }
        return re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }
}

/// Mirrors `guess_type` in the shell helper.
public enum TypeGuess {
    public static func of(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = content.split(whereSeparator: \.isNewline)
        if lines.count <= 1, trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://"),
           !trimmed.contains(where: \.isWhitespace) {
            return "url"
        }
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return "json" }
        let codeStarts = ["def ", "class ", "import ", "from ", "function ", "const ", "let ",
                          "var ", "#include", "package ", "public ", "private ", "async "]
        for line in lines {
            let l = line.trimmingCharacters(in: .whitespaces)
            if codeStarts.contains(where: { l.hasPrefix($0) }) { return "code" }
        }
        return "text"
    }
}
