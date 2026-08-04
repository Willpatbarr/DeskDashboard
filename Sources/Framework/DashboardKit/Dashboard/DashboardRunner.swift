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

    public var attachedWidgetSnapshots: [AttachedWidgetSnapshot] {
        dashboard.attachedWidgetSnapshots
    }
}
