// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "icloud_reminders_manager",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "icloud_reminders_manager",
            dependencies: [],
            path: "Sources/icloud_reminders_manager"
        ),
        .testTarget(
            name: "icloud_reminders_managerTests",
            dependencies: ["icloud_reminders_manager"]
        ),
    ]
)
