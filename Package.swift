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
        .executableTarget(
            name: "DeskDashboard",
            dependencies: ["DashboardKit"]
        ),
        .testTarget(
            name: "DeskDashboardTests",
            dependencies: ["DashboardKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
