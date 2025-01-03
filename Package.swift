// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "icloud_reminders_manager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]),
        .library(
            name: "TestHelpers",
            targets: ["TestHelpers"]),
        .executable(
            name: "CLI",
            targets: ["CLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            resources: [
                .process("config.json")
            ]),
        .target(
            name: "TestHelpers",
            dependencies: [
                .target(name: "Core")
            ]),
        .executableTarget(
            name: "CLI",
            dependencies: [
                .target(name: "Core")
            ],
            exclude: ["Info.plist"]),
        .testTarget(
            name: "CoreTests",
            dependencies: [
                .target(name: "Core"),
                .target(name: "TestHelpers")
            ],
            resources: [
                .process("Resources")
            ])
    ]
)
