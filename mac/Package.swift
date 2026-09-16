// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartClipMac",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "SmartClipCore"),
        .executableTarget(name: "SmartClipMac", dependencies: ["SmartClipCore"]),
        .testTarget(name: "SmartClipCoreTests", dependencies: ["SmartClipCore"]),
    ]
)
