// PushIngest.swift — HTTP ingest endpoints external producers POST readings to.

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
    /// `(path, handler)` for bare GET routes — matches `HTTPServer.register(path:handler:)`.
    public typealias RegisterGet = (String, @escaping () -> HTTPResponse) -> Void

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

    // MARK: - Claude sessions (`/ingest/claude-sessions`)

    /// Accepts the AgentManager daemon's snapshot:
    /// `{ "columns": [{id, label}], "sessions": [{id, title, project?, state,
    /// stalled?, askPending?, agentCount?, lastActivity?, ageSeconds}] }`,
    /// stores it, logs the push, and echoes the counts. `state` is the column id.
    public static func registerClaudeSessions(
        registerPost: RegisterPost,
        store: PushClaudeSessionsService
    ) {
        /// One subagent in a session's `agents` array. Every field optional for
        /// the same reason the session's are — see below.
        struct AgentPayload: Decodable {
            var label: String?
            var agentType: String?
            var model: String?
            var running: Bool?
            var seconds: Int?
            var failed: Bool?
        }
        // Everything but `id`, `title` and `state` is OPTIONAL, and that is
        // load-bearing rather than lax: the decode below is a single
        // all-or-nothing `decode`, so one required field an older producer
        // doesn't send yet blanks the entire board rather than dropping a fact.
        struct SessionPayload: Decodable {
            var id: String
            var title: String
            var project: String?
            var model: String?
            var attention: String?
            var attentionColor: String?
            var stage: String?
            var blockedOn: String?
            var branch: String?
            var prNumber: Int?
            var prState: String?
            var prReviewDecision: String?
            var state: String
            var stalled: Bool?
            /// Legacy alias for `blockedOn == "question"`; still sent so a Pi
            /// running an older build keeps flagging pending questions.
            var askPending: Bool?
            var agentCount: Int?
            var lastActivity: String?
            var ageSeconds: Int?
            // Detail-panel facts. A producer that predates the panel simply
            // omits these and the board renders exactly as it did before.
            var agents: [AgentPayload]?
            var repo: String?
            var base: String?
            var worktree: Bool?
            var prIsDraft: Bool?
            var effort: String?
            var permissionMode: String?
            var planName: String?
        }
        struct ColumnPayload: Decodable {
            var id: String
            var label: String
            var color: String?
            var compact: Bool?
        }
        struct Payload: Decodable {
            var columns: [ColumnPayload]?
            var sessions: [SessionPayload]
            /// Shape version of the push body, from the daemon's own
            /// `WIRE_VERSION`. Optional because a producer old enough to
            /// predate the field is exactly the case being detected — see the
            /// `?? 1` below.
            var wireVersion: Int?
        }

        registerPost("/ingest/claude-sessions") { body in
            guard let payload = try? JSONDecoder().decode(Payload.self, from: body) else {
                let received = String(decoding: body, as: UTF8.self)
                print("[ingest] claude-sessions <- rejected (invalid JSON); \(body.count) bytes: \(received.isEmpty ? "<empty>" : received.prefix(200))")
                return HTTPResponse(
                    contentType: "application/json",
                    body: Data(#"{"error":"expected JSON {columns?, sessions}"}"#.utf8)
                )
            }

            // Columns are optional in the payload but the reading always has
            // some — derive them from the sessions when the producer omits them.
            let columns = payload.columns?.map {
                ClaudeSessionColumn(
                    id: $0.id, label: $0.label, colorHex: $0.color, compact: $0.compact ?? false
                )
            }
                ?? orderedColumnIDs(of: payload.sessions.map(\.state))
                    .map { ClaudeSessionColumn(id: $0, label: $0.capitalized) }

            store.update(
                ClaudeSessionsReading(
                    columns: columns,
                    sessions: payload.sessions.map { session in
                        ClaudeSession(
                            id: session.id,
                            title: session.title,
                            project: session.project,
                            model: session.model,
                            attention: session.attention,
                            attentionColor: session.attentionColor,
                            stage: session.stage,
                            blockedOn: session.blockedOn,
                            branch: session.branch,
                            prNumber: session.prNumber,
                            prState: session.prState,
                            prReviewDecision: session.prReviewDecision,
                            column: session.state,
                            stalled: session.stalled ?? false,
                            askPending: session.askPending ?? false,
                            agentCount: session.agentCount ?? 0,
                            lastActivity: session.lastActivity,
                            ageSeconds: session.ageSeconds ?? 0,
                            // An agent with no label is unrenderable, so it is
                            // dropped rather than shown as a blank row.
                            agents: (session.agents ?? []).compactMap { agent in
                                guard let label = agent.label, !label.isEmpty else { return nil }
                                return ClaudeSessionAgent(
                                    label: label,
                                    agentType: agent.agentType,
                                    model: agent.model,
                                    running: agent.running ?? false,
                                    seconds: agent.seconds,
                                    failed: agent.failed ?? false
                                )
                            },
                            repo: session.repo,
                            base: session.base,
                            worktree: session.worktree ?? false,
                            prIsDraft: session.prIsDraft ?? false,
                            effort: session.effort,
                            permissionMode: session.permissionMode,
                            planName: session.planName
                        )
                    },
                    receivedAt: Date(),
                    // Absent means OLD: a producer that predates the field is
                    // precisely the stale-Mac case the flag exists to surface,
                    // so it must not inherit the current-version default.
                    wireVersion: payload.wireVersion ?? 1
                )
            )

            print("[ingest] claude-sessions <- \(payload.sessions.count) sessions in \(columns.count) columns (wire v\(payload.wireVersion ?? 1))")
            let echo = #"{"stored":\#(payload.sessions.count)}"#
            return HTTPResponse(
                contentType: "application/json",
                body: Data(echo.utf8)
            )
        }
    }

    /// Registers GET `/claude-focus-queue`: hands the Mac the focus taps queued
    /// on the Pi and clears them. Exists because the Mac can always reach the
    /// Pi, but a firewalled Mac can't accept the Pi's direct focus POSTs — the
    /// Mac's AgentManager polls this instead.
    public static func registerClaudeFocusQueue(
        registerGet: RegisterGet,
        store: PushClaudeSessionsService
    ) {
        registerGet("/claude-focus-queue") {
            let drained = store.drainPendingFocus()
            if !drained.isEmpty {
                print("[ingest] claude-focus-queue -> \(drained.joined(separator: ", "))")
            }
            let ids = drained.map { #""\#($0)""# }.joined(separator: ",")
            return HTTPResponse(
                contentType: "application/json",
                body: Data(#"{"focus":[\#(ids)]}"#.utf8)
            )
        }
    }

    /// Distinct column ids in first-seen order.
    private static func orderedColumnIDs(of states: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for state in states where seen.insert(state).inserted {
            ordered.append(state)
        }
        return ordered
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
