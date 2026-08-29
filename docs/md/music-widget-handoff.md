# Handoff: Music Widget (MVP widget #4)

## Context
Music is the 4th of the SDD's 5 MVP widgets (Clock → Alarm → Indoor Temp → **Music** → Outdoor Temp).
SDD §16 lists it as: *"Music — System now-playing — service push (event-driven)."*

Three widgets are already built and shipped on `MacMiniDev` (Clock, Alarm, Indoor Temperature),
each following the `Service → WidgetModel → Widget` pipeline with **zero changes to DashboardKit
core** (the LEGO Test). Music should do the same.

**Key head start:** the "service-push mechanism" the SDD said Music would force us to design is
*already built* — we did it for Indoor Temperature. Music reuses it wholesale (see Architecture).

## On HomeKit (asked up front)
HomeKit / HAP is an **accessory** protocol (lights, sensors, locks). It has **no** concept of
now-playing / media state — there is no characteristic for "current song." So Music cannot come
through HomeKit, full stop. That's fine; it was never the right tool. The correct analog to
"read the HomePod's temperature" is **read the HomePod's now-playing over the Apple TV / Companion
protocol using `pyatv`** — a different protocol from HAP. See Producer options below.

## Architecture (reuse, don't invent)
Identical shape to Indoor Temperature:
- A **push store** holds the latest `NowPlaying` value (thread-safe), fed by an external producer
  that POSTs to an ingest endpoint. This is the SDD §12 **service-push** path — already implemented
  for temperature in `DevHTTPServer` + the `/ingest/*` pattern in `DeskDashboard.swift`.
- The widget uses a **hybrid** strategy (SDD §12): a **1-second tick** re-reads the push store, so
  the tile reflects a new push within ~1s *and* can advance the track's elapsed time smoothly. This
  avoids building true event-driven re-rendering into the framework — the poll-on-tick model we
  already have is enough.

So: **no DashboardKit changes.** Everything lives in `DeskDashboardWidgets` + the executable.

## Files to create — `Sources/DeskDashboardWidgets/Music/`

Copy the structure of `Sources/DeskDashboardWidgets/IndoorTemperature/*` almost verbatim.

### `MusicService.swift`
```swift
public struct NowPlaying: Equatable, Sendable {
    public var title: String
    public var artist: String?
    public var album: String?
    public var isPlaying: Bool
    public var elapsed: TimeInterval?    // seconds into the track at `timestamp`
    public var duration: TimeInterval?
    public var timestamp: Date
    public init(...) { ... }
}

public protocol MusicService: DashboardService {
    func nowPlaying() -> NowPlaying?      // nil = nothing playing
}

public enum MusicServiceKeys {
    public static let nowPlaying = ServiceKey<AnyMusicService>("nowPlaying")
}

public final class AnyMusicService: MusicService { ... }          // copy AnyIndoorTemperatureService
public final class PushMusicService: MusicService, @unchecked Sendable { ... }  // copy PushIndoorTemperatureService
public final class SimulatedMusicService: MusicService { ... }    // dev: cycle a fake playlist
```

### `MusicWidgetModel.swift` (internal)
Transform layer. On each tick:
- `nil` → clear state (nothing playing).
- Else format `displayTitle`, `displaySubtitle` (artist · album), `isPlaying`.
- Compute **live elapsed** when playing: `elapsed + (tickDate - timestamp)`, clamped to `duration`.
- `displayProgress` like `"1:23 / 3:45"` (mm:ss). Reuse the countdown-formatting idea from
  `AlarmWidgetModel.countdownText`.

### `MusicWidget.swift` (public, `RenderableWidget`)
- Default config: title "Music", size `.medium`, **`refreshRate: .seconds(1)`** (the hybrid tick).
- `attach` resolves `MusicServiceKeys.nowPlaying`, falls back to `AnyMusicService(SimulatedMusicService())`.
- `render`:
  - `primaryText`: track title, or `"Nothing playing"`.
  - `secondaryText`: artist (· album), or the progress string.
  - `accessoryText`: `"PAUSED"` when `!isPlaying` (mirrors Alarm's `"RINGING"` badge use).
  - `metadata`: `Source`, and/or `Progress: 1:23 / 3:45`.
- Modifiers (composition over configuration): `.showAlbum(_:)`, maybe `.source(_:)`.

## Wiring — `Sources/DeskDashboard/DeskDashboard.swift`
Mirror the indoor-temperature wiring:
1. `let music = PushMusicService()` (optionally seed a demo track).
2. `.service(AnyMusicService(music), for: MusicServiceKeys.nowPlaying)` on the dashboard.
3. `runner.add(MusicWidget().id("music").title("Music"))`.
4. Add an ingest endpoint next to `registerIndoorTemperatureIngest`:
   `POST /ingest/now-playing` accepting flat JSON
   `{ "title": "...", "artist": "...", "album": "...", "isPlaying": true, "elapsed": 83, "duration": 225 }`,
   decode → `music.update(NowPlaying(...))`, log + echo. (The server already handles split TCP
   segments and `Expect: 100-continue`, so the endpoint just needs the decode/store/echo.)

## Producer options (what actually reads "now playing")
The producer runs on an Apple/Linux box and POSTs to `http://<host>:8642/ingest/now-playing`.
Pick by where the music plays:

- **Music plays on the HomePod / Apple TV → `pyatv`** (recommended; also runs on the Pi).
  `pip install pyatv`, pair once, then a small poller: `atvremote --id <ID> playing` → parse →
  POST. This is the true analog to the HomePod-temperature path (network protocol, not HAP).
- **Music plays in the Mac's Apple Music app → AppleScript.**
  `osascript -e 'tell application "Music" to get {name, artist, album, player state} of current track'`
  → format → POST.
- **Any app on the Mac (Spotify, browser, etc.) → `nowplaying-cli`** (open source, reads system
  MediaRemote now-playing).

Schedule the producer the same way as the temperature push: a `launchd` LaunchAgent on the host
running the poller every few seconds (see the working temp example:
`~/Library/LaunchAgents/com.willbarr.deskdashboard.temppush.plist`). Music is event-driven, but a
2–5s poll is plenty and far simpler than wiring MediaRemote change notifications.

## Tests — `Tests/DeskDashboardTests/MusicWidgetTests.swift`
Mirror `IndoorTemperatureWidgetTests` (fixed dates, `ManualDashboardClock`, formatter-matched
expectations):
- inert before attach (AD-004); `"Nothing playing"` with no data.
- renders title/artist/album; playing vs paused (`accessoryText`).
- elapsed advances across ticks when playing; does **not** advance when paused.
- progress string formatting (mm:ss, and the `duration` clamp).
- `PushMusicService` update/read; hybrid tick reflects a mid-cycle push.

## Known limitations / decisions to make
- **Album artwork can't be shown.** `WidgetContent` is text-only (title/primary/secondary/accessory
  + metadata) — there is no image field. This is the same render-contract gap flagged in the SDD
  alignment review. For the MVP, skip artwork; when the SwiftOpenUI layer is designed, decide
  whether to add an `artworkURL`/image affordance to `WidgetContent`. Don't add it just for Music.
- **True push-to-render vs. hybrid tick.** We're using the 1s hybrid tick (simplest, reuses
  everything). If sub-second responsiveness ever matters, that's a framework-level change (the
  renderer re-rendering on ingest) — out of scope for the MVP; leave a TODO per SDD §5.2.

## Verification (same as prior widgets)
1. `swift build` — clean; `swift test` — existing 89 pass + new Music tests.
2. Run on the **personal (unmanaged) mini**: `swift run -c release DeskDashboard`
   (release avoids the taskgated prompt; the managed work Mac's security stack blocks inbound LAN —
   see `memory/indoor-temp-homekit-source.md`).
3. Local check: `curl -X POST http://127.0.0.1:8642/ingest/now-playing -H 'Content-Type: application/json'
   -d '{"title":"Test","artist":"X","isPlaying":true,"elapsed":10,"duration":200}'` → expect an echo,
   and the Music tile updates within ~1s in the browser.
4. Then point the producer (pyatv / AppleScript / nowplaying-cli) at the endpoint on a launchd timer.
5. Confirm the diff touches **only** `Sources/DeskDashboardWidgets/Music/`, `DeskDashboard.swift`,
   and `Tests/` — nothing under `Sources/DashboardKit/` (the LEGO Test).

## Gotchas already solved (don't rediscover)
- Ingest body must be **flat** JSON (in Shortcuts: build the fields directly in Request Body, not a
  nested Dictionary). Not relevant if the producer is a script, but keep the endpoint tolerant.
- `DevHTTPServer` already reads the full `Content-Length` body and answers `Expect: 100-continue`.
- Only `localhost` works on the managed work Mac; use the personal mini or the Pi for real ingest.
