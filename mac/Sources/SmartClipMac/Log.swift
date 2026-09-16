import Foundation

/// `SMARTCLIP_DEBUG=1` turns on a trace of what the app is doing, which is the
/// only way to see inside a menu-bar app with no window of its own.
enum Log {
    static let enabled = ProcessInfo.processInfo.environment["SMARTCLIP_DEBUG"] == "1"

    static func debug(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        FileHandle.standardError.write(Data("[smartclip] \(message())\n".utf8))
    }
}
