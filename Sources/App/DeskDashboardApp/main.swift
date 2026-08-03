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

/// Writes a startup/diagnostic line to **stderr**.
///
/// Not `print`: when this runs as a service (the Pi kiosk under cage/sway),
/// stdout is a pipe rather than a tty, so the C library block-buffers it and
/// nothing reaches the journal until the buffer fills — which is why
/// `journalctl -u deskdashboard-ui` looked silent. stderr is unbuffered, and
/// journald captures it the same way. (`setvbuf(stdout, …)` would also work, but
/// Glibc declares `stdout` as a global `var`, which Swift 6 strict concurrency
/// rejects on Linux — it only compiles on Darwin.)
func log(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

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
    log("DeskDashboard UI: ingest server on :\(ingestServer.port)")
} catch {
    // Non-fatal: the UI still runs; push widgets keep their seeded data.
    log("warning: failed to start ingest server: \(error)")
}

// The layout/theme switcher (Clock, MTG, etc.) is shown by default; pass
// `--kiosk` to hide it for the fixed Pi display. (`--preview` still works as an
// explicit opt-in, so old launch commands keep behaving.)
let showsSwitcher = !CommandLine.arguments.contains("--kiosk")
    || CommandLine.arguments.contains("--preview")

// Type-scale nudge on top of the viewport-derived scale: `--scale 1.4`, or
// `DD_UI_SCALE=1.4` (easier for the Pi kiosk — a systemd `Environment=` drop-in
// needs no change to the sway/cage ExecStart line). The flag wins if both are set.
let scaleMultiplier: Double = {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--scale"),
       i + 1 < args.count,
       let value = Double(args[i + 1]), value > 0 {
        return value
    }
    if let env = ProcessInfo.processInfo.environment["DD_UI_SCALE"],
       let value = Double(env), value > 0 {
        return value
    }
    return 1
}()
if scaleMultiplier != 1 {
    log("DeskDashboard UI: type scale multiplier \(scaleMultiplier)×")
}

// `--window 1920x440` opens the window at a specific geometry, for previewing a
// target panel's shape (the Pi's strip display) from a desktop.
let windowSize: (width: Int, height: Int)? = {
    let args = CommandLine.arguments
    guard let i = args.firstIndex(of: "--window"), i + 1 < args.count else { return nil }
    let parts = args[i + 1].lowercased().split(separator: "x")
    guard parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]),
          w > 0, h > 0 else {
        log("warning: ignoring malformed --window '\(args[i + 1])' (expected WIDTHxHEIGHT)")
        return nil
    }
    log("DeskDashboard UI: window \(w)×\(h)")
    return (w, h)
}()

let renderer = SwiftCrossUIRenderer(
    theme: runner.dashboard.configuration.theme,
    showsPreviewControls: showsSwitcher,
    scaleMultiplier: scaleMultiplier,
    windowSize: windowSize
)
renderer.render(runner.attachedWidgetSnapshots)
runner.start { _ in
    renderer.render(runner.attachedWidgetSnapshots)
}
renderer.run()
