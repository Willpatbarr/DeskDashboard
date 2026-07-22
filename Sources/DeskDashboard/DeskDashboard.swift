import DashboardKit
import DeskDashboardDevTools
import DeskDashboardWidgets
import Foundation

// DeskDashboard executable — the APPLICATION layer. Composes the dashboard
// (widgets + their services), picks a dev renderer, and drives it from the
// runner's per-tick observer. All framework logic lives in DashboardKit.
@main
struct DeskDashboard {

    // MARK: - Entry point

    static func main() {
        // The push-backed stores are seeded here (so their tiles aren't empty at
        // launch) and shared between two places: the dashboard's services, which
        // read them, and the ingest endpoints, which overwrite them. Outdoor is
        // pull-based and owns its own fetch, so it needs no shared store here.
        let indoorTemperature = makeIndoorTemperatureStore()
        let music = makeMusicStore()

        let runner = DashboardRunner(
            dashboard: makeDashboard(
                indoorTemperature: indoorTemperature,
                music: music
            )
        )
        addWidgets(to: runner)

        startRenderer(
            for: runner,
            indoorTemperature: indoorTemperature,
            music: music
        )

        RunLoop.main.run()
    }

    // MARK: - Composition

    /// Builds the dashboard: theme + the five MVP widgets' services. Push
    /// services are passed in because the ingest endpoints also hold them; the
    /// alarm and outdoor sources are self-contained and created inline.
    private static func makeDashboard(
        indoorTemperature: PushIndoorTemperatureService,
        music: PushMusicService
    ) -> Dashboard {
        Dashboard()
            .theme(DarkDeskTheme())
            .service(
                AnyAlarmService(makeAlarmStore()),
                for: AlarmServiceKeys.alarms
            )
            .service(
                AnyIndoorTemperatureService(indoorTemperature),
                for: IndoorTemperatureServiceKeys.indoorTemperature
            )
            .service(
                AnyMusicService(music),
                for: MusicServiceKeys.nowPlaying
            )
            .service(
                AnyOutdoorTemperatureService(OpenMeteoOutdoorService()),
                for: OutdoorTemperatureServiceKeys.outdoorTemperature
            )
    }

    /// Registers the five MVP widgets, each configured with its id/title and
    /// any per-widget modifiers.
    private static func addWidgets(to runner: DashboardRunner) {
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
        runner.add(
            IndoorTemperatureWidget()
                .id("indoor")
                .title("Indoor")
        )
        runner.add(
            MusicWidget()
                .id("music")
                .title("Music")
                .source("HomePod")
        )
        runner.add(
            OutdoorTemperatureWidget()
                .id("outdoor")
                .title("Outdoor")
                .location("Rexburg, ID")
        )
    }

    // MARK: - Seeded stores

    private static func makeAlarmStore() -> LocalAlarmStore {
        let alarmStore = LocalAlarmStore()
        alarmStore.add(
            Alarm(
                id: "demo",
                label: "Demo alarm",
                date: Date().addingTimeInterval(120)
            )
        )
        return alarmStore
    }

    /// Push-backed indoor temperature, seeded so the tile isn't empty; then
    /// overwritten by POSTs to /ingest/indoor-temperature.
    private static func makeIndoorTemperatureStore() -> PushIndoorTemperatureService {
        PushIndoorTemperatureService(
            initialReading: TemperatureReading(
                celsius: 21.5,
                humidity: 44,
                timestamp: Date()
            )
        )
    }

    /// Push-backed now-playing, seeded with a demo track so the tile isn't
    /// empty; then overwritten by POSTs to /ingest/now-playing.
    private static func makeMusicStore() -> PushMusicService {
        PushMusicService(
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
    }

    // MARK: - Renderer

    /// Picks a dev renderer and drives it from the runner's per-tick observer.
    /// Both renderers are development tooling (DeskDashboardDevTools); the real
    /// UI arrives with the SwiftOpenUI layer.
    private static func startRenderer(
        for runner: DashboardRunner,
        indoorTemperature: PushIndoorTemperatureService,
        music: PushMusicService
    ) {
        if CommandLine.arguments.contains("--console") {
            let renderer = ConsoleRenderer()
            renderer.render(runner.attachedWidgetSnapshots)
            runner.start { _ in
                renderer.render(runner.attachedWidgetSnapshots)
            }
            return
        }

        let renderer = DevWebRenderer(
            theme: runner.dashboard.configuration.theme,
            port: port(from: CommandLine.arguments)
        )
        registerIndoorTemperatureIngest(on: renderer, store: indoorTemperature)
        registerNowPlayingIngest(on: renderer, store: music)

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

    // MARK: - Arguments

    private static func port(
        from arguments: [String]
    ) -> UInt16 {
        guard let index = arguments.firstIndex(of: "--port"),
              index + 1 < arguments.count,
              let value = UInt16(arguments[index + 1]) else {
            return 8642
        }

        return value
    }

    // MARK: - Indoor temperature ingest (the SDD §12 service-push path)

    /// Accepts JSON `{ "value": <number>, "unit": "C"|"F", "humidity": <number> }`,
    /// normalizes to Celsius, stores it, logs the push, and echoes what it stored.
    private static func registerIndoorTemperatureIngest(
        on renderer: DevWebRenderer,
        store: PushIndoorTemperatureService
    ) {
        struct Payload: Decodable {
            var value: Double
            var unit: String?
            var humidity: Double?
        }

        renderer.registerPost(path: "/ingest/indoor-temperature") { body in
            guard let payload = try? JSONDecoder().decode(Payload.self, from: body) else {
                let received = String(decoding: body, as: UTF8.self)
                print("[ingest] indoor-temperature <- rejected (invalid JSON); \(body.count) bytes: \(received.isEmpty ? "<empty>" : received)")
                return DevHTTPResponse(
                    contentType: "application/json",
                    body: Data(#"{"error":"expected JSON {value, unit?, humidity?}"}"#.utf8)
                )
            }

            let unit = (payload.unit ?? "C").uppercased()
            let celsius = unit == "F"
                ? (payload.value - 32) * 5 / 9
                : payload.value

            store.update(
                TemperatureReading(
                    celsius: celsius,
                    humidity: payload.humidity,
                    timestamp: Date()
                )
            )

            let stored = String(format: "%.1f", celsius)
            print("[ingest] indoor-temperature <- \(payload.value)°\(unit) => \(stored)°C")

            let humidityJSON = payload.humidity.map { String($0) } ?? "null"
            let echo = #"{"stored":"\#(stored)°C","humidity":\#(humidityJSON)}"#
            return DevHTTPResponse(
                contentType: "application/json",
                body: Data(echo.utf8)
            )
        }
    }

    // MARK: - Now-playing ingest (the SDD §12 service-push path)

    /// Accepts flat JSON
    /// `{ "title", "artist"?, "album"?, "isPlaying"?, "elapsed"?, "duration"? }`,
    /// stores it, logs the push, and echoes what it stored. A body with no
    /// `title` (or `{"stopped": true}`) clears the tile to "Nothing playing".
    private static func registerNowPlayingIngest(
        on renderer: DevWebRenderer,
        store: PushMusicService
    ) {
        struct Payload: Decodable {
            var title: String?
            var artist: String?
            var album: String?
            var isPlaying: Bool?
            var elapsed: Double?
            var duration: Double?
            var stopped: Bool?
        }

        renderer.registerPost(path: "/ingest/now-playing") { body in
            guard let payload = try? JSONDecoder().decode(Payload.self, from: body) else {
                let received = String(decoding: body, as: UTF8.self)
                print("[ingest] now-playing <- rejected (invalid JSON); \(body.count) bytes: \(received.isEmpty ? "<empty>" : received)")
                return DevHTTPResponse(
                    contentType: "application/json",
                    body: Data(#"{"error":"expected JSON {title, artist?, album?, isPlaying?, elapsed?, duration?}"}"#.utf8)
                )
            }

            guard payload.stopped != true, let title = payload.title, !title.isEmpty else {
                store.update(nil)
                print("[ingest] now-playing <- (nothing playing)")
                return DevHTTPResponse(
                    contentType: "application/json",
                    body: Data(#"{"stored":"nothing playing"}"#.utf8)
                )
            }

            store.update(
                NowPlaying(
                    title: title,
                    artist: payload.artist,
                    album: payload.album,
                    isPlaying: payload.isPlaying ?? true,
                    elapsed: payload.elapsed,
                    duration: payload.duration,
                    timestamp: Date()
                )
            )

            let state = (payload.isPlaying ?? true) ? "playing" : "paused"
            print("[ingest] now-playing <- \"\(title)\"\(payload.artist.map { " — \($0)" } ?? "") (\(state))")

            let echo = #"{"stored":"\#(title)","isPlaying":\#(payload.isPlaying ?? true)}"#
            return DevHTTPResponse(
                contentType: "application/json",
                body: Data(echo.utf8)
            )
        }
    }
}
