import DashboardHTTPServer
import DashboardKit
import DashboardUI
import DeskDashboardComposition
import Foundation

// DeskDashboard UI executable — the real SwiftCrossUI dashboard on the Pi's
// display. Composes the appliance from the shared `DeskDashboardComposition`
// (same widgets/services/ingest as the dev app) and drives `SwiftCrossUIRenderer`
// from the same per-tick observer. Album is dropped from the Music tile so its
// subtitle fits the narrower inline layout.

let system = makeDeskDashboardSystem(showsAlbum: false)
let runner = system.runner

// Sensor-push ingest on :8642 (override with --port), same endpoints the
// producers already POST to.
let ingestServer = HTTPServer(port: parsePort(CommandLine.arguments))
registerPushIngest(
    on: ingestServer.registerPost,
    indoorTemperature: system.indoorTemperature,
    music: system.music
)
do {
    try ingestServer.start()
    print("DeskDashboard UI: ingest server on :\(ingestServer.port)")
} catch {
    // Non-fatal: the UI still runs; push widgets keep their seeded data.
    print("warning: failed to start ingest server: \(error)")
}

let renderer = SwiftCrossUIRenderer(theme: runner.dashboard.configuration.theme)
renderer.render(runner.attachedWidgetSnapshots)
runner.start { _ in
    renderer.render(runner.attachedWidgetSnapshots)
}
renderer.run()
