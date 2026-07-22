# DeskDashboard — Next Steps

_Status as of 2026-07-22. Companion to [widget-progress.md](widget-progress.md)._

## Where we are

The **dev testing platform is complete**. All five MVP widgets (SDD §16) run
end-to-end with live data, cross-compiled to a static musl aarch64 binary on the
Raspberry Pi, driven through the `Service → WidgetModel → Widget` pipeline with
zero changes to DashboardKit core. 116 tests pass. Rendering currently goes
through the two **dev** renderers (`ConsoleRenderer` + `DevWebRenderer` on
`:8642`) — both are development tooling, not the product.

The engine and data plumbing are effectively done. What remains is turning this
from "runs and serves an HTML debug page" into the actual appliance: a real UI
on the Pi's physical display, with the hardening to run unattended.

## Remaining work

### 1. Real UI — SwiftOpenUI / SwiftCrossUI (the one remaining major phase)

The end goal is a real dashboard UI on the Pi's display, replacing the dev
renderers. This reuses the existing observer + layout machinery — the dev
renderers already prove the shape.

- [x] **De-risk the build first.** Done — see [ui-build-spike.md](ui-build-spike.md).
  Outcome: SwiftCrossUI builds fine on the macOS host (AppKit) but **cannot
  cross-compile against the static musl SDK** (a Glibc-only image dep + GTK's
  dynamic C libraries). The UI needs a **glibc build with GTK 4 on the Pi**
  (build natively on the Pi, or cross-compile with a glibc SDK). `build-pi.sh`
  (static musl) stays as-is for the dev `DeskDashboard` binary.
- [x] Add the SwiftCrossUI dependency to `Package.swift`. Added as a dependency
  of a **separate `deskdashboard-ui` product** so the musl build of
  `DeskDashboard` never pulls it.
- [x] Write a real `Renderer` that maps widget snapshots → views, driven from
  the same per-tick observer the dev renderers use. Done in `DeskDashboardUI`
  (`SwiftCrossUIRenderer` + `DashboardRootView`/`TileView`), with an entry point
  in `DeskDashboardUIApp`. Same `render(runner.attachedWidgetSnapshots)` call the
  dev renderers use.
- [x] Map `GridLayout` / `WidgetGridSlot` onto screen geometry — tiles are
  grouped into rows by `gridSlot.row`, ordered by `column`, in SwiftCrossUI
  stacks. (Column/row *spans* aren't width-weighted yet — tiles share each row
  evenly; a follow-up if the layout needs it.)
- [x] Wire the `/ingest/*` push endpoints into `DeskDashboardUIApp`. Done — the
  ingest handlers were extracted into a shared `PushIngest` (in
  DeskDashboardDevTools) used by both the dev app and the UI app; the UI app now
  runs the same `DevHTTPServer` on `:8642` (override `--port`). Verified
  end-to-end: POSTs to `/ingest/now-playing` and `/ingest/indoor-temperature`
  update the live stores. Stores are still seeded so tiles aren't empty at launch.
- [x] Set up the Pi build/run path for `deskdashboard-ui` (glibc + GTK 4).
  [`scripts/build-ui-pi.sh`](../scripts/build-ui-pi.sh) builds it natively on the
  Pi; full procedure in [pi-ui-deploy.md](pi-ui-deploy.md). **Verified on hardware
  2026-07-22** — builds and runs on the Pi with all five tiles live, music +
  indoor pushing in over `:8642`. Two glibc fixes were needed along the way
  (`SOCK_STREAM` → `Int32`; a low-memory build to avoid OOM — the script now caps
  jobs by RAM and silences swift-backtrace noise).
- [x] Drive it fullscreen / kiosk + auto-start (see §3). **Verified on hardware
  2026-07-22** — boots straight to the fullscreen dashboard under `cage`.

### 2. Image affordance in `WidgetContent`

- [ ] `WidgetContent` is currently text-only, which is why Music has no album
  artwork. Add an image affordance once the UI layer defines one, then wire up
  Music artwork. Gated behind #1 — don't add it just for the dev renderers.

### 3. Pi appliance hardening

- [x] **systemd auto-start + kiosk unit** so the dashboard survives reboot /
  crash and comes up fullscreen. **Done + verified on hardware 2026-07-22**:
  [`scripts/install-kiosk-pi.sh`](../scripts/install-kiosk-pi.sh) installs `cage`
  + a rate-limited `Restart=always` service on `tty1`; procedure + rollback in
  [pi-kiosk.md](pi-kiosk.md). Must boot to console first (cage needs the display
  to itself) — the doc has the safe order. Currently runs the **debug** binary;
  a `release` rebuild is a nice-to-have for the permanent fixture.
- [ ] **Linux timer robustness** — if the tick loop ever freezes under
  `RunLoop.main.run()` on Linux, switch `TimerDashboardClock` to a GCD
  `DispatchSourceTimer`. Not yet hit, but a known Linux caveat.
- [ ] Confirm the mini-side launchd producers (Indoor + Music) restart reliably
  across reboots/failures.

## Suggested order

1. **De-risk the SwiftCrossUI + static-SDK build** (small spike) — it may
   dictate everything downstream.
2. Build the real renderer against the existing observer/grid.
3. Add the `WidgetContent` image affordance + Music artwork.
4. systemd unit + timer hardening to finish it as an appliance.

## Out of scope / non-goals

- **More widgets** — the MVP set (SDD §16) is complete. No widget work is planned
  unless the scope expands beyond the original five.
- **Sub-second push-to-render** — would require a framework-level change
  (renderer re-rendering on ingest). The hybrid tick is sufficient for the MVP.
</content>
</invoke>
