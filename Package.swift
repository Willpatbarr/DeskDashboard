// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeskDashboard",
    products: [
        .library(
            name: "DashboardKit",
            targets: ["DashboardKit"]
        ),
        .executable(
            name: "DeskDashboard",
            targets: ["DeskDashboard"]
        ),
    ],
    targets: [
        .target(
            name: "DashboardKit"
        ),
        .target(
            name: "DeskDashboardWidgets",
            dependencies: ["DashboardKit"]
        ),
        // Development-only tooling (console + web renderers). Not part of the
        // shipping dashboard; delete or ignore for production builds.
        .target(
            name: "DeskDashboardDevTools",
            dependencies: ["DashboardKit"]
        ),
        .executableTarget(
            name: "DeskDashboard",
            dependencies: [
                "DashboardKit",
                "DeskDashboardWidgets",
                "DeskDashboardDevTools",
            ]
        ),
        .testTarget(
            name: "DeskDashboardTests",
            dependencies: ["DashboardKit", "DeskDashboardWidgets"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
