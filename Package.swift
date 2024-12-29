// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "icloud_reminders_manager",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "icloud_reminders_manager",
            targets: ["App"]
        ),
    ],
    targets: [
        .target(
            name: "Core",
            dependencies: []
        ),
        .target(
            name: "Managers",
            dependencies: ["Core"]
        ),
        .executableTarget(
            name: "App",
            dependencies: ["Core", "Managers"]
        ),
        .testTarget(
            name: "icloud_reminders_managerTests",
            dependencies: ["Core", "Managers", "App"]
        ),
    ]
)
