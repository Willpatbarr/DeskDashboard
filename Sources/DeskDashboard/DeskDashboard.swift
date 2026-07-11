import DashboardKit

@main
struct DeskDashboard {
    static func main() {
        var dashboard = Dashboard()
            .theme(DarkDeskTheme())

        dashboard.add(
            ClockWidget()
                .id("clock")
                .title("Clock")
                .size(.large)
        )

        print("DeskDashboard ready with \(dashboard.attachedWidgetCount) widget.")
    }
}
