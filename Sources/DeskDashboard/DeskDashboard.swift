import DashboardKit

@main
struct DeskDashboard {
    static func main() {
        let dashboard = Dashboard()
            .theme(DarkDeskTheme())
        let runner = DashboardRunner(dashboard: dashboard)

        runner.add(
            ClockWidget()
                .id("clock")
                .title("Clock")
                .size(.large)
                .showSeconds()
        )

        print("DeskDashboard ready with \(runner.attachedWidgetSnapshots.count) widget.")
    }
}
