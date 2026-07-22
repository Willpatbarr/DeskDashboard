// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeskDashboard",
    // SwiftCrossUI (via DeskDashboardUI) requires macOS 10.15+; raise the floor
    // so the UI target resolves. DashboardKit itself stays platform-neutral.
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "DashboardKit",
            targets: ["DashboardKit"]
        ),
        .executable(
            name: "DeskDashboard",
            targets: ["DeskDashboard"]
        ),
        // The real SwiftCrossUI dashboard UI. A SEPARATE product from
        // `DeskDashboard` on purpose: `scripts/build-pi.sh` builds
        // `--product DeskDashboard` against the static musl SDK, and SwiftCrossUI
        // can't cross-compile there (GTK + a Glibc-only image dep). Keeping the
        // UI in its own product means the musl build never pulls SwiftCrossUI.
        .executable(
            name: "deskdashboard-ui",
            targets: ["DeskDashboardUIApp"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/stackotter/swift-cross-ui",
            from: "0.8.0"
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
        // Sensor-push ingest: the dependency-free HTTP server + the shared
        // `/ingest/*` endpoint registration. A real (non-dev) component — both
        // the dev app and the real UI app feed their push widgets through it.
        .target(
            name: "DashboardIngest",
            dependencies: ["DashboardKit", "DeskDashboardWidgets"]
        ),
        // Development-only renderers (console + web).
        .target(
            name: "DeskDashboardDevTools",
            dependencies: ["DashboardKit", "DeskDashboardWidgets", "DashboardIngest"]
        ),
        // The one declarative definition of the appliance (widgets + services +
        // seed data + ingest wiring), shared by both executables. No SwiftCrossUI,
        // so the static-musl product can use it.
        .target(
            name: "DeskDashboardComposition",
            dependencies: ["DashboardKit", "DeskDashboardWidgets", "DashboardIngest"]
        ),
        .executableTarget(
            name: "DeskDashboard",
            dependencies: [
                "DashboardKit",
                "DeskDashboardDevTools",
                "DeskDashboardComposition",
            ]
        ),
        // The real UI: maps widget snapshots -> SwiftCrossUI views, driven from
        // the same per-tick observer the dev renderers use. Reuses DashboardKit
        // with zero changes to core (the LEGO Test). Uses DefaultBackend
        // (AppKit on macOS, GTK on Linux/Pi).
        .target(
            name: "DeskDashboardUI",
            dependencies: [
                "DashboardKit",
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "DefaultBackend", package: "swift-cross-ui"),
            ]
        ),
        // Application entry point for the real UI. Composes the dashboard
        // (widgets + services) and drives the SwiftCrossUI renderer.
        .executableTarget(
            name: "DeskDashboardUIApp",
            dependencies: [
                "DeskDashboardUI",
                "DeskDashboardComposition",
                "DashboardIngest",
            ]
        ),
        .testTarget(
            name: "DeskDashboardTests",
            dependencies: ["DashboardKit", "DeskDashboardWidgets"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
