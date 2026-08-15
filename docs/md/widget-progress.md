# DeskDashboard — Widget Progress

_Status as of 2026-07-22._

## Summary

All **five MVP widgets** from SDD §16 are built, tested, and running end-to-end
on the Raspberry Pi with live data. Every widget follows the
`Service → WidgetModel → Widget` pipeline with **zero changes to DashboardKit
core** (the LEGO Test holds). The dev web renderer (`DevWebRenderer`) serves the
tiles as an HTML page; the real SwiftOpenUI UI is still future work.

| # | Widget | Data source | Update strategy | Status |
|---|--------|-------------|-----------------|--------|
| 1 | Clock | System time | Clock tick, 1s | ✅ Done |
| 2 | Alarm | Local alarm store | Clock tick, 1s (state check) | ✅ Done |
| 3 | Indoor Temperature | HomePod via HomeKit → push | `/ingest/indoor-temperature`, 30s tick | ✅ Done |
| 4 | Music | HomePod via pyatv → push | `/ingest/now-playing`, hybrid 1s tick | ✅ Done |
| 5 | Outdoor Temperature | Open-Meteo API → pull | Fetch every 10 min, 15s display tick | ✅ Done |

## Per-widget detail

### 1. Clock
System time. Large tile, `showSeconds()`. Falls back to the system clock when no
time service is injected.

### 2. Alarm
Reads a local alarm store; each tick picks the soonest enabled alarm and formats
a countdown, or shows a `RINGING` badge within the firing window.

### 3. Indoor Temperature (push)
`PushIndoorTemperatureService` holds the latest reading, overwritten by POSTs to
`/ingest/indoor-temperature`. Renders temperature (°F default, `°C` modifier) +
humidity, with a `STALE` badge after ~150 s without a push. Source is the
HomePod's HomeKit temperature — read on a Mac (HomeKit is Mac-only) and pushed
over HTTP.

### 4. Music (push)
`PushMusicService` holds the latest `NowPlaying`, overwritten by POSTs to
`/ingest/now-playing`. Uses the **hybrid** strategy: a 1 s tick re-reads the
store *and* advances the track position live between pushes. Renders title,
`artist · album`, a `PAUSED` badge, and `Source` / `Progress` metadata.
Album artwork is intentionally omitted (WidgetContent is text-only for the MVP).

### 5. Outdoor Temperature (pull)
`OpenMeteoOutdoorService` fetches Open-Meteo (free, no API key) over URLSession
and caches the result, gated to one network fetch per 10 min. Hardcoded to
**Rexburg, ID** (43.826, −111.7897) via an overridable `Location`. Renders
temperature (°F default), a condition label mapped from the WMO weather code, a
`STALE` badge, and `Location` metadata. The 15 s widget tick is a display cadence
only — it re-reads the cache so first paint and staleness show promptly.

## Data sources & producers

- **Push widgets** (Indoor, Music) are fed by external *producers* that POST to
  the dev HTTP server's `/ingest/*` endpoints. See `producers/README.md`.
  - Music: `producers/now-playing-push.py` reads the HomePod via pyatv
    (`atvscript`) on a launchd timer.
  - Indoor: a macOS Shortcut (launchd `com.willbarr.deskdashboard.temppush`)
    reads HomeKit and POSTs.
- **Pull widget** (Outdoor) needs no producer — the app fetches Open-Meteo
  itself, so it works anywhere with internet.

## Deployment status

Running on the **Raspberry Pi** (aarch64, 64-bit Raspberry Pi OS, `192.168.4.244`)
as the **display hub**, with the **Mac mini as the sensor gateway**:

- The Pi runs the dashboard and serves the dev web page on `:8642`.
- The mini runs the Indoor + Music producers, POSTing over the LAN to the Pi
  (both HomePod-sourced, and only a Mac can read the HomePod).
- Clock and Outdoor are self-contained on the Pi.

Built by **cross-compiling from the Mac** with the swift.org toolchain + the
Static Linux SDK, producing a fully-static musl aarch64 binary (no Swift or libs
needed on the Pi). One command: `bash scripts/build-pi.sh`. Required one
portability fix — `DevHTTPServer` now imports `Musl` alongside `Darwin`/`Glibc`.

## Tests

`swift test` → **116 passing** (89 framework/earlier + 14 Music + 13 Outdoor).
Widget tests use fixed dates and a `ManualDashboardClock`, mirroring the Indoor
test style (inert-before-attach, formatting, staleness, push/pull behavior).

## Known limitations / next steps

- **No album artwork** — `WidgetContent` is text-only. Revisit when the
  SwiftOpenUI layer defines an image affordance; don't add it just for Music.
- **Hybrid tick, not true push-to-render** — sub-second responsiveness would be
  a framework-level change (renderer re-rendering on ingest); out of scope.
- **Linux timer caveat** (not yet hit) — `Timer` + `RunLoop.main.run()` can be
  unreliable on Linux; if the tick loop ever freezes on the Pi, switch
  `TimerDashboardClock` to a GCD `DispatchSourceTimer`.
- **Pi auto-start** — not set up (the Pi stays on). A systemd unit would make it
  survive terminal-close / crashes / reboots when it graduates to an appliance.
- **Real UI** — current renderers (console + web) are development tooling; the
  SwiftOpenUI/SwiftCrossUI UI on the Pi display is the next major phase.
