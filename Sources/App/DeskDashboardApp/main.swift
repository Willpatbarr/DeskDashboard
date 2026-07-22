import DashboardHTTPServer
import DashboardKit
import DashboardUI
import DeskDashboardComposition
import Foundation

// The REAL executable (product `deskdashboard-ui`): the graphical SwiftCrossUI
// dashboard that runs fullscreen on the Pi's display. Composes the same appliance
// as the dev app (via `DeskDashboardComposition`) but drives the real
// `SwiftCrossUIRenderer` from the same per-tick observer. Album is dropped from
// the Music tile so its subtitle fits the narrower inline layout. For the
// text/web development front-end, see `DeskDashboardDevApp` (product
// `deskdashboard-dev`).

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

// The layout/theme switcher (Clock, MTG, etc.) is shown by default; pass
// `--kiosk` to hide it for the fixed Pi display. (`--preview` still works as an
// explicit opt-in, so old launch commands keep behaving.)
let showsSwitcher = !CommandLine.arguments.contains("--kiosk")
    || CommandLine.arguments.contains("--preview")
let renderer = SwiftCrossUIRenderer(
    theme: runner.dashboard.configuration.theme,
    showsPreviewControls: showsSwitcher
)
renderer.render(runner.attachedWidgetSnapshots)
runner.start { _ in
    renderer.render(runner.attachedWidgetSnapshots)
}
renderer.run()
