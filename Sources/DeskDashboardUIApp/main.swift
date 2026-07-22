import DashboardKit
import DeskDashboardDevTools
import DeskDashboardUI
import DeskDashboardWidgets
import Foundation

// DeskDashboard UI executable — the real SwiftCrossUI dashboard on the Pi's
// display. Mirrors the dev-renderer application (`DeskDashboard`) but drives
// `SwiftCrossUIRenderer` instead of the console/web renderers, from the SAME
// per-tick observer (`runner.start { renderer.render(...) }`).
//
// The HTTP `/ingest/*` push endpoints (Indoor + Music producers) are served by
// the same dependency-free `DevHTTPServer` the dev renderer uses, via the shared
// `PushIngest` registration. Producers POST to `:8642` on the Pi (override with
// `--port`). The stores are still seeded so tiles aren't empty before first push.

// MARK: - Seeded stores

/// Push-backed indoor temperature, seeded so the tile isn't empty.
let indoorTemperature = PushIndoorTemperatureService(
    initialReading: TemperatureReading(
        celsius: 21.5,
        humidity: 44,
        timestamp: Date()
    )
)

/// Push-backed now-playing, seeded with a demo track.
let music = PushMusicService(
    initialNowPlaying: NowPlaying(
        title: "Nightcall",
        artist: "Kavinsky",
        album: "OutRun",
        isPlaying: true,
        elapsed: 42,
        duration: 258,
        timestamp: Date()
    )
)

let alarms = LocalAlarmStore()
alarms.add(
    Alarm(
        id: "demo",
        label: "Demo alarm",
        date: Date().addingTimeInterval(120)
    )
)

// MARK: - Composition

let theme = DarkDeskTheme()

let dashboard = Dashboard()
    .theme(theme)
    .service(AnyAlarmService(alarms), for: AlarmServiceKeys.alarms)
    .service(
        AnyIndoorTemperatureService(indoorTemperature),
        for: IndoorTemperatureServiceKeys.indoorTemperature
    )
    .service(AnyMusicService(music), for: MusicServiceKeys.nowPlaying)
    .service(
        AnyOutdoorTemperatureService(OpenMeteoOutdoorService()),
        for: OutdoorTemperatureServiceKeys.outdoorTemperature
    )

let runner = DashboardRunner(dashboard: dashboard)

runner.add(ClockWidget().id("clock").title("Clock").size(.large).showSeconds())
runner.add(AlarmWidget().id("alarm").title("Alarm"))
runner.add(IndoorTemperatureWidget().id("indoor").title("Indoor"))
// Album dropped so the subtitle (just the artist) fits the narrower inline tile.
runner.add(MusicWidget().id("music").title("Music").source("HomePod").showAlbum(false))
runner.add(
    OutdoorTemperatureWidget().id("outdoor").title("Outdoor").location("Rexburg, ID")
)

// MARK: - Ingest server (sensor push)

/// Port for the ingest HTTP server. Defaults to 8642; override with `--port N`.
func ingestPort(from arguments: [String]) -> UInt16 {
    guard let index = arguments.firstIndex(of: "--port"),
          index + 1 < arguments.count,
          let value = UInt16(arguments[index + 1]) else {
        return 8642
    }
    return value
}

let ingestServer = DevHTTPServer(port: ingestPort(from: CommandLine.arguments))
PushIngest.registerIndoorTemperature(
    registerPost: ingestServer.registerPost,
    store: indoorTemperature
)
PushIngest.registerNowPlaying(
    registerPost: ingestServer.registerPost,
    store: music
)

do {
    try ingestServer.start()
    print("DeskDashboard UI: ingest server on :\(ingestServer.port)")
} catch {
    // Non-fatal: the UI still runs, push widgets just keep their seeded data.
    print("warning: failed to start ingest server: \(error)")
}

// MARK: - Render

let renderer = SwiftCrossUIRenderer(theme: theme)
renderer.render(runner.attachedWidgetSnapshots)
runner.start { _ in
    renderer.render(runner.attachedWidgetSnapshots)
}
renderer.run()
