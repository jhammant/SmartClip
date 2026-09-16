import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())

if arguments.contains("--version") {
    print("SmartClip for Mac 0.1.0")
    exit(0)
}

// `SmartClip --show` opens the picker in the already-running app, so a script,
// a Raycast command or a test can trigger it without a keystroke.
if arguments.contains("--show") {
    DistributedNotificationCenter.default().postNotificationName(
        AppDelegate.showPickerNotification, object: nil, userInfo: nil, deliverImmediately: true)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
app.run()
