import DashboardKit
import DeskDashboardWidgets
import Foundation

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

        let renderer = ConsoleRenderer()
        renderer.render(runner.attachedWidgetSnapshots)

        runner.start { _ in
            renderer.render(runner.attachedWidgetSnapshots)
        }

        RunLoop.main.run()
    }
}
