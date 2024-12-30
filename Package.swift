// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "icloud_reminders_manager",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "icloud_reminders_manager",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-enable-bare-slash-regex"])
            ]
        ),
        .testTarget(
            name: "icloud_reminders_managerTests",
            dependencies: [
                "icloud_reminders_manager",
                .product(name: "Logging", package: "swift-log")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
