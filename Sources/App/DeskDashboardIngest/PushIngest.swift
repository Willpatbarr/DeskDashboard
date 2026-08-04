import DashboardHTTPServer
import DeskDashboardWidgets
import Foundation

/// The SDD §12 sensor-push ingest endpoints, shared by the dev web renderer and
/// the real UI app so both parse identical payloads and log identically.
///
/// Registration is parameterized over a `registerPost` hook rather than a
/// concrete server, so callers can pass either `DevWebRenderer.registerPost` or
/// `HTTPServer.registerPost`.
public enum PushIngest {
    /// `(path, handler)` — matches both `DevWebRenderer.registerPost(path:handler:)`
    /// and `HTTPServer.registerPost(path:handler:)`.
    public typealias RegisterPost = (String, @escaping (Data) -> HTTPResponse) -> Void

    // MARK: - Indoor temperature (`/ingest/indoor-temperature`)

    /// Accepts JSON `{ "value": <number>, "unit": "C"|"F", "humidity": <number> }`,
    /// normalizes to Celsius, stores it, logs the push, and echoes what it stored.
    public static func registerIndoorTemperature(
        registerPost: RegisterPost,
        store: PushIndoorTemperatureService
    ) {
        struct Payload: Decodable {
            var value: Double
            var unit: String?
            var humidity: Double?
        }

        registerPost("/ingest/indoor-temperature") { body in
            guard let payload = try? JSONDecoder().decode(Payload.self, from: body) else {
                let received = String(decoding: body, as: UTF8.self)
                print("[ingest] indoor-temperature <- rejected (invalid JSON); \(body.count) bytes: \(received.isEmpty ? "<empty>" : received)")
                return HTTPResponse(
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
            return HTTPResponse(
                contentType: "application/json",
                body: Data(echo.utf8)
            )
        }
    }

    // MARK: - Now playing (`/ingest/now-playing`)

    /// Accepts flat JSON
    /// `{ "title", "artist"?, "album"?, "isPlaying"?, "elapsed"?, "duration"? }`,
    /// stores it, logs the push, and echoes what it stored. A body with no
    /// `title` (or `{"stopped": true}`) clears the tile to "Nothing playing".
    public static func registerNowPlaying(
        registerPost: RegisterPost,
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

        registerPost("/ingest/now-playing") { body in
            guard let payload = try? JSONDecoder().decode(Payload.self, from: body) else {
                let received = String(decoding: body, as: UTF8.self)
                print("[ingest] now-playing <- rejected (invalid JSON); \(body.count) bytes: \(received.isEmpty ? "<empty>" : received)")
                return HTTPResponse(
                    contentType: "application/json",
                    body: Data(#"{"error":"expected JSON {title, artist?, album?, isPlaying?, elapsed?, duration?}"}"#.utf8)
                )
            }

            guard payload.stopped != true, let title = payload.title, !title.isEmpty else {
                store.update(nil)
                print("[ingest] now-playing <- (nothing playing)")
                return HTTPResponse(
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
            return HTTPResponse(
                contentType: "application/json",
                body: Data(echo.utf8)
            )
        }
    }
}
