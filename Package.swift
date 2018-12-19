// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tipsy",
    dependencies: [
        .package(url: "https://github.com/jakeheis/SwiftCLI", .upToNextMinor(from: "5.2.0")),
        .package(url: "https://github.com/tuist/xcodeproj.git", .upToNextMinor(from: "6.3.0")),
        .package(url: "https://github.com/kylef/PathKit", .upToNextMinor(from: "0.9.2")),
    ],
    targets: [
        .target(
            name: "Tipsy",
            dependencies: ["TipsyCore"]),
        .target(
            name: "TipsyCore",
            dependencies: ["SwiftCLI", "xcodeproj", "PathKit"]),
        .testTarget(
            name: "TipsyTests",
            dependencies: ["Tipsy"]),
    ]
)
