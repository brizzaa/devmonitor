// swift-tools-version: 5.9

import PackageDescription

// DevMonitor is a macOS app. The core library and its tests also build on Linux,
// which is how the parsing and project logic is verified without Xcode.
// The executable target compiles a stub on Linux; SwiftUI sources are wrapped in
// `#if os(macOS)` and type-check when the package is opened on a Mac.
let package = Package(
    name: "DevMonitor",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "DevMonitorCore", targets: ["DevMonitorCore"]),
        .executable(name: "DevMonitor", targets: ["DevMonitor"]),
    ],
    targets: [
        .target(
            name: "DevMonitorCore",
            path: "Sources/DevMonitorCore"
        ),
        .executableTarget(
            name: "DevMonitor",
            dependencies: ["DevMonitorCore"],
            path: "Sources/DevMonitor"
        ),
        .testTarget(
            name: "DevMonitorCoreTests",
            dependencies: ["DevMonitorCore"],
            path: "Tests/DevMonitorCoreTests"
        ),
    ]
)
