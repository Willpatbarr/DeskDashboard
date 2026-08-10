// Composition.swift — The one declarative definition of the appliance: widgets, services, theme.

import DashboardHTTPServer
import DashboardKit
import DeskDashboardIngest
import DeskDashboardWidgets
import Foundation

// The single, declarative definition of the DeskDashboard appliance, shared by
// both the dev (`DeskDashboard`) and real-UI (`deskdashboard-ui`) executables so
// the widget list, services, seed data, and ingest wiring live in exactly one
// place. No SwiftCrossUI dependency, so the static-musl build can use it too.

/// The composed system: the runner to drive, plus the two push stores the
/// ingest endpoints overwrite.
public struct DeskDashboardSystem {
    public let runner: DashboardRunner
    public let indoorTemperature: PushIndoorTemperatureService
    public let music: PushMusicService
    /// Shared MTG game state, so every life/turn widget reads one game.
    public let mtgGame: InMemoryMTGGameService
}

/// Builds the five-widget dashboard with its services and seeded push stores.
///
/// - Parameter showsAlbum: whether the Music tile includes the album in its
///   subtitle (the inline UI layout turns this off to fit the narrower tile).
public func makeDeskDashboardSystem(showsAlbum: Bool = true) -> DeskDashboardSystem {
    // Push stores are seeded so their tiles aren't empty before the first push,
    // and handed back so the ingest endpoints can overwrite them.
    let indoorTemperature = PushIndoorTemperatureService(
        initialReading: TemperatureReading(celsius: 21.5, humidity: 44, timestamp: Date())
    )
    // One game shared by all the MTG seats — the turn number is common, and life
    // is per seat keyed by widget id.
    let mtgGame = InMemoryMTGGameService()

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
    alarms.add(Alarm(id: "demo", label: "Demo alarm", date: Date().addingTimeInterval(120)))

    // Each widget carries its own service via `.service(…)`, so the data source
    // reads right next to the widget it feeds. (Clock has none — it falls back
    // to the system clock.) The push stores are also handed to the ingest
    // endpoints below so external producers can overwrite them.
    let dashboard = Dashboard()
        // The dashboard's real theme. Arrangements that don't name their own use this,
        // and the app chrome always sizes from it — so editing this line actually
        // changes what you see (it previously did not: the renderer's hardcoded
        // catalogue overrode it for every screen).
        // `RuledGreenTheme`, not `GreenBoardTheme`: the ruled take on the green
        // board — flat, outlined tiles, one green for all tile chrome — is now what
        // every board wears, not just the "Ruled" arrangement. `GreenBoardTheme`
        // (gradient surfaces, caption 18) is kept for reference and is currently
        // unused.
        .theme(RuledGreenTheme())
        .widgets {
            ClockWidget()
                .id("clock")
                .title("Clock")
                .size(.large)
                .showSeconds()
                .layout(.bigNumber)
            AlarmWidget()
                .id("alarm")
                .title("Alarm")
                .service(alarms)
            IndoorTemperatureWidget()
                .id("indoor")
                .title("Indoor")
                .service(indoorTemperature)
            MusicWidget()
                .id("music")
                .title("Music")
                .source("HomePod")
                .showAlbum(showsAlbum).service(music)
            LifeCounterWidget(id: "life1", game: mtgGame)
            LifeCounterWidget(id: "life2", game: mtgGame)
            LifeCounterWidget(id: "life3", game: mtgGame)
            LifeCounterWidget(id: "life4", game: mtgGame)
            TurnCounterWidget(game: mtgGame)
            OutdoorTemperatureWidget()
                .id("outdoor")
                .title("Outdoor")
                .location("Rexburg, ID")
                .service(OpenMeteoOutdoorService())
        }

    return DeskDashboardSystem(
        runner: DashboardRunner(dashboard: dashboard),
        indoorTemperature: indoorTemperature,
        music: music,
        mtgGame: mtgGame
    )
}

/// Registers both sensor-push ingest endpoints against a server's `registerPost`
/// hook (works with `DevWebRenderer.registerPost` or a bare `HTTPServer`).
public func registerPushIngest(
    on registerPost: PushIngest.RegisterPost,
    indoorTemperature: PushIndoorTemperatureService,
    music: PushMusicService
) {
    PushIngest.registerIndoorTemperature(registerPost: registerPost, store: indoorTemperature)
    PushIngest.registerNowPlaying(registerPost: registerPost, store: music)
}

/// Parses `--port N` from the argument list, defaulting to 8642.
public func parsePort(_ arguments: [String], default defaultPort: UInt16 = 8642) -> UInt16 {
    guard let index = arguments.firstIndex(of: "--port"),
          index + 1 < arguments.count,
          let value = UInt16(arguments[index + 1]) else {
        return defaultPort
    }
    return value
}
