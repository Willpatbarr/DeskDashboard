// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Sources/ is grouped into three layers:
//   Framework/  — the reusable dashboard engine + infra (no app/renderer specifics)
//   Renderers/  — reusable backends that render any dashboard's snapshots
//   App/        — everything specific to *this* dashboard (widgets, services,
//                 ingest, composition, executables). Delete App/ and Framework +
//                 Renderers still stand as a usable framework.
let package = Package(
    name: "DeskDashboard",
    // SwiftCrossUI (via DashboardUI) requires macOS 10.15+; raise the floor so
    // the UI target resolves. DashboardKit itself stays platform-neutral.
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
        // ─────────────────────────── Framework ───────────────────────────
        // The reusable dashboard engine: Dashboard/Widget/WidgetModel, the
        // ServiceKey + environment plumbing, layout, theme, the DashboardBuilder
        // DSL, and the DashboardRenderer + ServiceBackedWidget protocols.
        .target(
            name: "DashboardKit",
            path: "Sources/Framework/DashboardKit"
        ),
        // Dependency-free socket HTTP server. Reusable infra used by the web
        // renderer and by the app's ingest endpoints.
        .target(
            name: "DashboardHTTPServer",
            path: "Sources/Framework/DashboardHTTPServer"
        ),

        // ─────────────────────────── Renderers ───────────────────────────
        // Reusable — each renders any dashboard's [AttachedWidgetSnapshot].
        .target(
            name: "DashboardDevRenderers",
            dependencies: ["DashboardKit", "DashboardHTTPServer"],
            path: "Sources/Renderers/DashboardDevRenderers"
        ),
        .target(
            name: "DashboardUI",
            dependencies: [
                "DashboardKit",
                .product(name: "SwiftCrossUI", package: "swift-cross-ui"),
                .product(name: "DefaultBackend", package: "swift-cross-ui"),
            ],
            path: "Sources/Renderers/DashboardUI"
        ),

        // ────────────────────────────── App ──────────────────────────────
        // Everything specific to this dashboard.
        .target(
            name: "DeskDashboardWidgets",
            dependencies: ["DashboardKit"],
            path: "Sources/App/DeskDashboardWidgets"
        ),
        // App-specific /ingest/* endpoints that know about this app's push stores.
        .target(
            name: "DeskDashboardIngest",
            dependencies: ["DashboardKit", "DashboardHTTPServer", "DeskDashboardWidgets"],
            path: "Sources/App/DeskDashboardIngest"
        ),
        // The one declarative definition of the appliance (widgets + services +
        // seed data + ingest wiring). No SwiftCrossUI, so the musl product can use it.
        .target(
            name: "DeskDashboardComposition",
            dependencies: [
                "DashboardKit",
                "DeskDashboardWidgets",
                "DeskDashboardIngest",
                "DashboardHTTPServer",
            ],
            path: "Sources/App/DeskDashboardComposition"
        ),
        .executableTarget(
            name: "DeskDashboard",
            dependencies: [
                "DashboardKit",
                "DashboardDevRenderers",
                "DashboardHTTPServer",
                "DeskDashboardComposition",
            ],
            path: "Sources/App/DeskDashboard"
        ),
        .executableTarget(
            name: "DeskDashboardUIApp",
            dependencies: [
                "DashboardUI",
                "DashboardHTTPServer",
                "DeskDashboardComposition",
            ],
            path: "Sources/App/DeskDashboardUIApp"
        ),
        .testTarget(
            name: "DeskDashboardTests",
            dependencies: ["DashboardKit", "DeskDashboardWidgets"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
