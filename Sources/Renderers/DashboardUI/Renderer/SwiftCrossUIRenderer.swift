// SwiftCrossUIRenderer.swift — Entry point of the real renderer: snapshots in, app launched.

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

    /// - Parameters:
    ///   - arrangements: the app's selectable arrangements, in switcher order;
    ///     index 0 is what boots. Empty means "render the dashboard as its
    ///     composition describes it" — configured theme, each widget's own
    ///     layout, in the tile grid.
    ///   - showsSwitcher: when true, the UI shows a button that cycles
    ///     through built-in theme × layout combinations (the `--preview` flag) —
    ///     for eyeballing configurations, not for the shipping kiosk. It also
    ///     shows the viewport/scale readout in the header.
    ///   - scaleMultiplier: manual nudge on top of the viewport-derived type
    ///     scale (`--scale N` / `DD_UI_SCALE`), for dialing in a real display
    ///     without rebuilding.
    ///   - windowSize: the window's opening size, or `nil` for the default
    ///     (the theme reference canvas). `--window 1920x440` reproduces the Pi's
    ///     panel geometry on a desktop.
    ///   - slideMilliseconds: duration of the preview pill's highlight slide, or
    ///     `nil` for the default. `0` disables the animation — an escape hatch for
    ///     a display whose backend can't draw frames fast enough.
    ///   - frameMilliseconds: gap between hand-stepped animation frames, or `nil`
    ///     for the default (~60fps). Sweep it on the target display to find the
    ///     real budget; `DD_UI_LOG=1` reports the cadence achieved.
    public init(
        theme: any Theme,
        arrangements: [Arrangement] = [],
        showsSwitcher: Bool = false,
        scaleMultiplier: Double = 1,
        windowSize: (width: Int, height: Int)? = nil,
        slideMilliseconds: Double? = nil,
        frameMilliseconds: Double? = nil,
        onAction: ((String, String) -> Void)? = nil
    ) {
        let model = DashboardModel(
            theme: theme,
            arrangements: arrangements,
            showsSwitcher: showsSwitcher,
            scaleMultiplier: scaleMultiplier
        )
        self.model = model
        DashboardLaunch.model = model
        if let windowSize {
            DashboardLaunch.windowSize = windowSize
            DashboardLaunch.forcedWindowSize = windowSize
        }
        if let slideMilliseconds, slideMilliseconds >= 0 {
            DashboardLaunch.slideMilliseconds = slideMilliseconds
        }
        model.onAction = onAction
        if let frameMilliseconds, frameMilliseconds > 0 {
            DashboardLaunch.frameSeconds = frameMilliseconds / 1000
        }
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
