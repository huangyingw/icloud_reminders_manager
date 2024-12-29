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
        .target(
            name: "icloud_reminders_manager_core",
            dependencies: [],
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "icloud_reminders_manager",
            dependencies: ["icloud_reminders_manager_core"],
            path: "Sources/App"
        ),
        .testTarget(
            name: "icloud_reminders_managerTests",
            dependencies: ["icloud_reminders_manager_core"]
        ),
    ]
)
