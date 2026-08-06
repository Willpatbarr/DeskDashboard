// DashboardRunner.swift — Drives a dashboard: ticks widgets, publishes snapshots.

import Foundation

public final class DashboardRunner {
    public private(set) var dashboard: Dashboard
    public let clock: any DashboardClock

    public init(
        dashboard: Dashboard,
        clock: any DashboardClock = TimerDashboardClock()
    ) {
        self.dashboard = dashboard
        self.clock = clock
    }

    public var isRunning: Bool {
        clock.isRunning
    }

    public func start(
        onTick: ((DashboardTick) -> Void)? = nil
    ) {
        clock.start(
            every: dashboard.configuration.refreshRate
        ) { [weak self] date in
            guard let self else {
                return
            }

            self.dashboard.tick(at: date)
            onTick?(DashboardTick(date: date))
        }
    }

    public func stop() {
        clock.stop()
    }

    @discardableResult
    public func add<W: Widget>(
        _ widget: W
    ) -> WidgetID {
        dashboard.add(widget)
    }

    /// Routes a tap from a renderer to the widget that raised it.
    ///
    /// The renderer only *emits* `(id, action)`; the app wires that here. That
    /// keeps input flowing the same direction as everything else — the framework
    /// never reaches into a renderer.
    ///
    /// Ignores ids that aren't attached, and widgets that aren't interactive, so a
    /// stale tap can't crash the kiosk.
    public func perform(action: String, on widgetID: WidgetID) {
        dashboard.perform(action: action, on: widgetID)
    }

    public var attachedWidgetSnapshots: [AttachedWidgetSnapshot] {
        dashboard.attachedWidgetSnapshots
    }
}
