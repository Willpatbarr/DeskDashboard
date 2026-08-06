// DeskDashboardDevApp.swift — Entry point of the dev executable: same composition, dev renderers.

import DashboardDevRenderers
import DashboardHTTPServer
import DashboardKit
import DeskDashboardComposition
import Foundation

// The DEVELOPMENT executable (product `deskdashboard-dev`). Composes the same
// appliance as the real app (via `DeskDashboardComposition`) but renders it with
// the dev tools — the console renderer (`--console`) or the web debug page on
// :8642 (`--port` to override). No GUI deps, so this is what cross-compiles to
// the static-musl Pi binary via scripts/build-pi.sh. For the real graphical
// dashboard, see the `DeskDashboardApp` target (product `deskdashboard-ui`).
@main
struct DeskDashboardDevApp {
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
