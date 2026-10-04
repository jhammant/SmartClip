// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartClipMac",
    platforms: [.macOS(.v13)],
    products: [
        // The clipboard engine without SmartClip's menu-bar icon, for apps that host it (Roost).
        .library(name: "SmartClipKit", targets: ["SmartClipKit", "SmartClipCore"]),
        .executable(name: "SmartClipMac", targets: ["SmartClipMac"]),
    ],
    targets: [
        .target(name: "SmartClipCore"),
        .target(name: "SmartClipKit", dependencies: ["SmartClipCore"]),
        .executableTarget(name: "SmartClipMac", dependencies: ["SmartClipKit", "SmartClipCore"]),
        .testTarget(name: "SmartClipCoreTests", dependencies: ["SmartClipCore"]),
    ]
)
