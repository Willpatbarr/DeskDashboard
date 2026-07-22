import DashboardKit

/// The real dashboard renderer, built on SwiftCrossUI.
///
/// It exposes the same `render(_:)` shape as the dev renderers
/// (`ConsoleRenderer`, `DevWebRenderer`), so it drops into the exact same
/// per-tick observer:
///
/// ```swift
/// let renderer = SwiftCrossUIRenderer(theme: theme)
/// renderer.render(runner.attachedWidgetSnapshots)          // first paint
/// runner.start { _ in renderer.render(runner.attachedWidgetSnapshots) }
/// renderer.run()                                           // runs the UI loop
/// ```
///
/// `render(_:)` pushes snapshots into the observable model; SwiftCrossUI
/// observes the change and re-renders. `run()` launches the app and drives the
/// backend's main loop (replacing `RunLoop.main.run()`).
///
/// - Note: The observer tick fires on the main thread (the backend's run loop),
///   which is where SwiftCrossUI state must be mutated. On Linux this depends on
///   the tick source being serviced by the GTK loop — see the `DispatchSourceTimer`
///   caveat in the docs if ticks ever stall on the Pi.
public final class SwiftCrossUIRenderer: DashboardRenderer, @unchecked Sendable {
    private let model: DashboardModel

    public init(theme: any Theme) {
        let model = DashboardModel(theme: theme)
        self.model = model
        DashboardLaunch.model = model
    }

    /// Publishes a new set of widget snapshots to the UI.
    public func render(_ snapshots: [AttachedWidgetSnapshot]) {
        model.snapshots = snapshots
    }

    /// Launches the SwiftCrossUI app and runs the backend's main loop. Blocks
    /// for the lifetime of the app; call after wiring up the observer.
    @MainActor
    public func run() {
        DashboardApp.main()
    }
}
