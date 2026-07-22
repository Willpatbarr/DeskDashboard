import Foundation

/// A sink for rendered dashboard state. Every renderer — the console/web dev
/// tools and the real SwiftCrossUI UI — receives the same
/// `[AttachedWidgetSnapshot]` on each tick, so the composition can drive *a*
/// `DashboardRenderer` without knowing which one.
///
/// Lifecycle is modeled with two defaulted hooks so the driver stays uniform:
/// `start()` for renderers that need to spin something up (the web server), and
/// `run()` for the one that owns the main loop (SwiftCrossUI). Renderers only
/// implement the hooks they need.
public protocol DashboardRenderer {
    /// Publish a fresh set of widget snapshots.
    func render(_ snapshots: [AttachedWidgetSnapshot])

    /// Start any background work (e.g. an HTTP server). Default: nothing.
    func start() throws

    /// Run the blocking main loop for the lifetime of the app. Default: the
    /// Foundation run loop (correct for the console/web renderers, which keep
    /// running via their own threads/timers).
    @MainActor func run()
}

public extension DashboardRenderer {
    func start() throws {}
    @MainActor func run() { RunLoop.main.run() }
}
