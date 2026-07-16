import DashboardKit
import DeskDashboardDevTools
import DeskDashboardWidgets
import Foundation

@main
struct DeskDashboard {
    static func main() {
        let alarmStore = LocalAlarmStore()
        alarmStore.add(
            Alarm(
                id: "demo",
                label: "Demo alarm",
                date: Date().addingTimeInterval(120)
            )
        )

        let dashboard = Dashboard()
            .theme(DarkDeskTheme())
            .service(
                AnyAlarmService(alarmStore),
                for: AlarmServiceKeys.alarms
            )
        let runner = DashboardRunner(dashboard: dashboard)

        runner.add(
            ClockWidget()
                .id("clock")
                .title("Clock")
                .size(.large)
                .showSeconds()
        )
        runner.add(
            AlarmWidget()
                .id("alarm")
                .title("Alarm")
        )

        // Both renderers are development tooling (DeskDashboardDevTools);
        // the real UI arrives with the SwiftOpenUI layer.
        if CommandLine.arguments.contains("--console") {
            let renderer = ConsoleRenderer()
            renderer.render(runner.attachedWidgetSnapshots)
            runner.start { _ in
                renderer.render(runner.attachedWidgetSnapshots)
            }
        } else {
            let renderer = DevWebRenderer(
                theme: runner.dashboard.configuration.theme
            )
            do {
                try renderer.start()
            } catch {
                print("Failed to start dev web renderer: \(error)")
                exit(1)
            }

            renderer.render(runner.attachedWidgetSnapshots)
            runner.start { _ in
                renderer.render(runner.attachedWidgetSnapshots)
            }
        }

        RunLoop.main.run()
    }
}
