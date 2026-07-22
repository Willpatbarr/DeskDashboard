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

- [ ] **De-risk the build first.** Confirm SwiftCrossUI/SwiftOpenUI
  cross-compiles against the **Static Linux musl SDK** used in
  `scripts/build-pi.sh`. This is the biggest unknown — it may force a toolchain
  change (e.g. a glibc dynamic build instead of static musl). Spike this before
  committing to the rest.
- [ ] Add the SwiftCrossUI/SwiftOpenUI dependency to `Package.swift`.
- [ ] Write a real `Renderer` that maps widget snapshots → views, driven from
  the same per-tick observer the dev renderers use
  (`DeskDashboard.startRenderer`).
- [ ] Map `GridLayout` / `WidgetPlacement` onto real screen geometry.
- [ ] Drive the UI fullscreen / kiosk on the Pi display — decide framebuffer vs.
  X / Wayland.

### 2. Image affordance in `WidgetContent`

- [ ] `WidgetContent` is currently text-only, which is why Music has no album
  artwork. Add an image affordance once the UI layer defines one, then wire up
  Music artwork. Gated behind #1 — don't add it just for the dev renderers.

### 3. Pi appliance hardening

- [ ] **systemd auto-start unit** so the dashboard survives reboot / crash /
  terminal-close. Not yet set up (the Pi currently just stays on).
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
