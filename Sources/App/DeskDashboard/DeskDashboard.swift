import DashboardDevRenderers
import DashboardHTTPServer
import DashboardKit
import DeskDashboardComposition
import Foundation

// DeskDashboard executable — development front-end. Composes the appliance from
// the shared `DeskDashboardComposition` (single source of truth for widgets,
// services, and ingest) and drives a dev renderer: the console renderer with
// `--console`, otherwise the web renderer on :8642 (override with `--port`).
@main
struct DeskDashboard {
    static func main() {
        let system = makeDeskDashboardSystem()
        let runner = system.runner

        if CommandLine.arguments.contains("--console") {
            let renderer = ConsoleRenderer()
            renderer.render(runner.attachedWidgetSnapshots)
            runner.start { _ in renderer.render(runner.attachedWidgetSnapshots) }
            RunLoop.main.run()
            return
        }

        let renderer = DevWebRenderer(
            theme: runner.dashboard.configuration.theme,
            port: parsePort(CommandLine.arguments)
        )
        registerPushIngest(
            on: renderer.registerPost,
            indoorTemperature: system.indoorTemperature,
            music: system.music
        )

        do {
            try renderer.start()
        } catch {
            print("Failed to start dev web renderer: \(error)")
            exit(1)
        }

        renderer.render(runner.attachedWidgetSnapshots)
        runner.start { _ in renderer.render(runner.attachedWidgetSnapshots) }
        RunLoop.main.run()
    }
}
