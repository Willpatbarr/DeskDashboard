# Running the real UI on the Pi (glibc + GTK)

_Status as of 2026-07-22. Companion to [ui-build-spike.md](ui-build-spike.md)._

The `deskdashboard-ui` product is the real SwiftCrossUI dashboard. Unlike the
dev `DeskDashboard` binary, it **cannot** be the static-musl cross-compile that
[`scripts/build-pi.sh`](../scripts/build-pi.sh) produces — SwiftCrossUI's
GtkBackend links GTK 4 (dynamic C libraries) and a transitive dep hard-codes
`import Glibc`, both of which the musl SDK can't satisfy (details in
[ui-build-spike.md](ui-build-spike.md)). So the UI is a **glibc build with GTK 4
present**, built **natively on the Pi**.

| Binary | Toolchain | Built by | GTK? |
|--------|-----------|----------|------|
| `DeskDashboard` (dev renderers) | static musl, cross-compiled from Mac | `scripts/build-pi.sh` | no |
| `deskdashboard-ui` (real UI) | glibc, native on the Pi | `scripts/build-ui-pi.sh` | **yes** |

> **Not yet verified on hardware.** These steps follow from the build spike and
> SwiftCrossUI's stated GTK requirement, but the on-Pi build/run hasn't been run
> yet (the Pi wasn't reachable when this was written). Treat the first run as the
> verification.

## 1. One-time prerequisites (on the Pi)

A Swift toolchain must already be installed and on `PATH` (the Pi has one). Then:

```bash
sudo apt update
sudo apt install -y libgtk-4-dev clang pkg-config
```

`libgtk-4-dev` provides the `gtk4` pkg-config module SwiftCrossUI's GtkBackend
links against; `clang` is required by that backend.

## 2. Build

From the repo on the Pi:

```bash
bash scripts/build-ui-pi.sh          # release; CONFIG=debug for debug
```

The script preflights `swift`, `pkg-config`, `clang`, and `gtk4`, then runs
`swift build -c release --product deskdashboard-ui` and prints the binary path
(`.build/release/deskdashboard-ui`). Expect the first build to be slow —
SwiftCrossUI pulls swift-syntax macros and image libraries.

## 3. Run

The app opens a GTK window, so it needs a graphical session (Wayland or X). From
a terminal inside the Pi's desktop session:

```bash
.build/release/deskdashboard-ui           # ingest server on :8642
.build/release/deskdashboard-ui --port 9000
```

It also starts the sensor-push ingest server (`/ingest/now-playing`,
`/ingest/indoor-temperature`) on `:8642` — the **same port and endpoints** the
dev binary served, so the Mac-mini producers need no reconfiguration.

## 4. Fullscreen / kiosk (follow-up)

SwiftCrossUI has **no in-app fullscreen API** — fullscreen/kiosk is a compositor
concern, not something the app sets. Options:

- **Kiosk compositor:** run the app under [`cage`](https://github.com/cage-kiosk/cage)
  (a single-app Wayland kiosk): `cage -- .build/release/deskdashboard-ui`.
- **Desktop WM:** launch it in the existing Wayland/X session and let the window
  manager fullscreen it (e.g. labwc/wayfire window rules).

Auto-start at boot + restart-on-crash is the **systemd unit** in
[next-steps.md](next-steps.md) §3 — do that alongside picking the kiosk approach
above so the dashboard survives reboots and comes up fullscreen.
