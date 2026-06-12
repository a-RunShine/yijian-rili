// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "一键日历",
    defaultLocalization: "zh",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "一键日历",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "一键日历Tests",
            dependencies: ["一键日历"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
