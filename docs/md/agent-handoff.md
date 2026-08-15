# Agent handoff — UI work on the Pi

_Written 2026-08-04, after a long session of native-UI layout/typography work._

Everything an agent needs to keep working on the SwiftCrossUI dashboard: how the
three machines fit together, how to actually see what you changed, and the
backend traps that cost the last session a dozen wasted deploys.

## 1. The three machines

| Role | Host | Path | Notes |
|---|---|---|---|
| **Where the agent runs** | work MacBook `YY699XMK-6FC71A.local` | `/Users/willbarr/Developer/DeskDashboard` | edits, `swift build`, `swift test`. **No GitHub credentials** — `git ls-remote` fails with "Repository not found". Commits here go nowhere. |
| **Where pushes happen** | mini `williambarr@192.168.4.220` | `~/Documents/DeskDashboard` | key-based SSH from the MacBook. Git identity is the personal account; `origin` is SSH (`git@github.com:Willpatbarr/DeskDashboard.git`) so pushes work headlessly. |
| **The display** | Pi `willbarr@192.168.4.244` | `~/Desktop/DeskDashboard-MacMiniDev` | key-based SSH. Runs the kiosk. Branch is **`master`**, no upstream — pull with `git pull --ff-only origin MacMiniDev`. |

Working branch is `MacMiniDev` throughout.

Sync code with **tar over SSH**, not rsync (macOS ships openrsync, which hangs on
`-c` / `--out-format`):

```bash
COPYFILE_DISABLE=1 tar -cf - Sources Tests | ssh willbarr@192.168.4.244 \
  'cd ~/Desktop/DeskDashboard-MacMiniDev && tar -xf -'
```

Two traps in that one line:

- **`COPYFILE_DISABLE=1` is not optional.** Without it macOS `tar` emits an
  AppleDouble `._Foo.swift` sidecar for every file carrying an extended
  attribute. They don't break the build (SwiftPM skips dot-files), so they
  accumulate silently — 41 of them had piled up by 2026-08-05 — and they *do*
  corrupt any `find`/`grep` audit of the tree. Clean up with
  `find Sources Tests -name '._*' -delete` on the Pi.
- **`tar -xf` never deletes.** After moving or renaming files, the Pi keeps the
  copies at their old paths, so the next build sees duplicate declarations.
  `rm -rf` the affected directory on the Pi *before* extracting.

And when diffing file lists between the two machines, sort both with
`LC_ALL=C sort` — macOS and Linux collate `+` differently, which makes `comm`
report identical filenames as missing from both sides.

## 2. The loop that makes UI work possible

The panel is the only place the real geometry happens, and it can't be
screenshotted from a dev machine — but it *can* be driven over SSH. Use this
instead of guessing; the session that preceded this doc spent five rounds
"fixing" things blind and none of them landed.

**Build + restart on the Pi.** `swift` isn't on the PATH for a non-login shell
(swiftly puts it in the profile), and `sudo` needs `-n`:

```bash
ssh willbarr@192.168.4.244 'export PATH="$HOME/.local/share/swiftly/bin:$PATH";
  cd ~/Desktop/DeskDashboard-MacMiniDev &&
  CONFIG=debug JOBS=1 bash scripts/build-ui-pi.sh 2>&1 | grep -E "^error|error:|built:";
  sudo -n systemctl restart deskdashboard-ui'
```

`JOBS=1` keeps the 4 GB Pi from OOM-ing.

**The kiosk now runs the RELEASE binary**, so `CONFIG=debug` builds something the
panel will not pick up — a silent no-op deploy. Use `CONFIG=release` (slow: ~20 min
on the Pi vs ~1 min for debug) or point the panel back at debug while iterating.

**The binary path is NOT in the systemd unit.** `zz-sway.conf` overrides `ExecStart`
to run `sway -c ~/.config/sway/kiosk.conf`, and that file `exec`s the binary. So
switching builds is a one-line edit there, then a restart:

```bash
ssh willbarr@192.168.4.244 \
  'sed -i "s#\.build/debug/#.build/release/#" ~/.config/sway/kiosk.conf &&
   sudo -n systemctl restart deskdashboard-ui'
```

`~/.config/sway/kiosk.conf.debug-bak` is the pre-switch copy, and the debug binary is
still on disk, so falling back is instant.

**Release bought ~20% CPU, not speed.** Measured with `/proc/<pid>/stat` tick deltas:
idle 10s 271→211 ticks, 8s hold 640→528. Frame cadence was unchanged (51–53fps,
mean 19–20ms both) because the animation is timer-paced at `asked=20ms` and the Pi
has headroom — it is not CPU-bound, so optimisation can't show up there. Don't
re-run this experiment expecting a visible win; the input latency in §A was the
thing that actually felt slow.

Building release safely on the Pi: `JOBS=1`, `nice -n 19`, and a watchdog that kills
the build if available RAM drops under 250M with under 300M swap free — so the build
dies rather than the kernel picking off the kiosk or sshd. Worst point observed was
624M available with swap barely touched, and output goes to `.build/release/` so the
running binary is untouched and there's no downtime.

**Screenshot it** (sway/wlroots, so `grim` works):

```bash
ssh willbarr@192.168.4.244 'export XDG_RUNTIME_DIR=/run/user/$(id -u);
  export WAYLAND_DISPLAY=$(basename $(ls $XDG_RUNTIME_DIR/wayland-* | grep -v "\.lock" | head -1));
  grim /tmp/dash.png'
scp willbarr@192.168.4.244:/tmp/dash.png .   # then Read it — images render inline
```

**Tap the UI** via sway IPC (no physical touch needed):

```bash
export SWAYSOCK=$(ls /run/user/1000/sway-ipc.* | head -1)
swaymsg seat seat0 cursor set 1825 30
swaymsg seat seat0 cursor press button1
swaymsg seat seat0 cursor release button1
```

A restart resets the preview to index 0, so tap to reach the one you want. Pill
slot centres at 1920×440 are roughly **1783 / 1825 / 1867** for slots 1/2/3.

**Measure, don't eyeball.** Decode the PNG and compare a tile column against an
adjacent *gap* column at the same row — that cancels the vertical gradient. This
is how the missing bottom margin (tile ran to y=439 of 440) and the invisible
panels (2/255 contrast) were both found. `DD_UI_LOG=1` also makes the app print
its computed geometry once per distinct value.

**Verify your edit actually landed.** Three deploys were wasted measuring plain
text and reporting it as changed, because a scripted edit's anchor silently
didn't match. `grep` for the new code before deploying.

## 2b. Performance: where the time actually goes

Profiled with a poor-man's profiler, because the Pi has no `perf` but does have
`gdb` (`sudo gdb -p <pid> -batch -ex "bt 40"` in a loop, then aggregate the frames).
Debug builds give good Swift symbols. Find the pid with `pgrep -x deskdashboard-u` —
**not** `pgrep -f deskdashboard-ui`, which matches your own command line and will
happily `pkill` your SSH session.

The profile is almost entirely `ViewGraphNode.computeLayout` recursion, bottoming out
in `GtkBackend.size(of:whenDisplayedIn:)` → `gtk_widget_create_pango_context`. **A
Pango context was being built and destroyed for every text measurement, on every
layout pass.** Measured on the MTG board, per update:

| | MTG idle 10s | ticks during a 6-tap run |
|---|---|---|
| before (debug) | 271 ticks | — |
| skip identical snapshots | 163 | — |
| + reuse the widget's Pango context | 98 | 167 |
| + single-child `.centered` fast path | 74 | 152 |
| + release build (what ships now) | **40** | **91** |

**Net: idle CPU down 85%, interaction work down ~45%** from where this session started.

(`/proc/<pid>/stat` fields 14+15, 100 ticks = 1 core-second.)

⚠️ **Don't quote a "ms per update" derived as `(busy − idle)`** — that subtracts a
baseline which itself shrinks as things get faster, so the number goes UP while the
app gets faster. It fooled me once. Compare raw ticks over a fixed interaction
instead.

Two fixes, only one of which is ours:

1. **`SwiftCrossUIRenderer.render` drops snapshots equal to the current ones.** The
   runner ticks every second but the clock only changes once a minute, so most passes
   were re-laying-out a pixel-identical screen. Verified the clock still advances.
2. **`Pango(for:)` should use `gtk_widget_get_pango_context` (the widget's own,
   kept current by GTK) instead of `gtk_widget_create_pango_context` (a fresh one),
   with a `g_object_ref` to balance the existing `deinit` unref.** This is a 3×
   win on the update path and rendering is pixel-identical across every font size
   on both boards — but it lives in **`stackotter/swift-cross-ui` 0.8.0**, not here.

Fix 2 lives in `patches/swift-cross-ui-pango-context.patch` and
**`scripts/build-ui-pi.sh` re-applies it on every build**, after `swift package
resolve` and before `swift build`. SwiftPM has no patch mechanism, so this is the
alternative to forking; the script is idempotent, and if the patch ever stops
applying (a dependency bump) it prints a loud WARNING and builds anyway rather than
failing — a slow panel beats a broken one, but silence would be worst of all.
Verified by reverting the checkout by hand and rebuilding: `patch: … (applied)`.
Still worth upstreaming.

Residual risk if text ever looks mis-measured: the widget's own context reflects its
*current* style, so if SwiftCrossUI ever measured before GTK recomputed style after a
CSS font-size change, a size could be stale. Not observed across every font size on
all five boards — but the fresh-context version could not have that problem by
construction, so suspect this first.

Fix 3, ours: **`.centered` with a single child skips the VStack entirely**
(`TileView`). The stack exists to space and align siblings, and a lone child has
none, but SwiftCrossUI still paid for the whole VStack + ForEach subtree every pass —
and `computeStackLayout` is the hottest frame once Pango is fixed. Guarded on
`lift == 0` so the optical-alignment path is untouched. All five boards verified
pixel-identical.

After all three, the profile is flat: no single hot function, just `computeLayout`
recursion over the view tree. Further gains need FEWER NODES, not a faster call —
i.e. real layout restructuring, with the regression risk that implies on this
backend. Diminishing returns start here.

**Don't measure input latency or render cost with `swaymsg` alone.** Injected pointer
events stop delivering `pressed` for a while after an update (only `released` keeps
arriving), so a 5-tap burst registers once — real touch does not behave that way.
Tap *timing* is measurable this way; tap *throughput* is not.

## 3. Backend traps (all verified on the panel)

SwiftCrossUI's GTK backend behaves unlike SwiftUI in ways that will eat your day:

- **`.cornerRadius` must be applied by the PARENT.** Inside a child `View`
  struct's own body it doesn't clip that view's composited background. Hence
  `tileCorners(_:)` in `ThemeToSCUIPalette.swift`, called at every tile call site.
- **A bare `HStack`/`VStack` with no background reports no size.** Drop the
  background or the explicit `.frame(height:)` from the preview pill and the whole
  control vanishes *and stops receiving taps*. Same trap collapses any stack used
  for text layout.
- **Never `.padding(.vertical:)` around a greedy child** (`maxHeight: .infinity`) —
  the inset is swallowed.
- **`minHeight` loses to a greedy sibling.** Split the screen with exact
  `.frame(height:)` bands.
- **A `.frame(height:)` shorter than a label's natural box does not centre text** —
  it pushes glyphs *down* out of their box so siblings draw through them. Tried
  three times; don't.
- **Negative padding and negative stack spacing DO work**, and are the levers
  for optical alignment.
- **Real letter-spacing IS reachable on GTK** despite SwiftCrossUI having no
  tracking API: `Text.inspect(.afterUpdate) { (label: Gtk.Label) in ... }`
  (GtkBackend-only modifier) exposes the label's per-widget CSS class, which
  accepts GTK 4's `letter-spacing`. See `TextToGTKTracking.swift` — and keep the
  `import Gtk` quarantined there; Gtk exports its own `Color`/`Font` and makes
  every other file's type lookup ambiguous. `.afterUpdate` is required because
  `updateTextView` clears+re-sets CSS on every update (in `computeLayout`,
  before `commit`). Layout measures text untracked so the box runs a few px
  wide, but GtkLabel centres its ink (xalign 0.5), so centred text stays put.
- **Adding or removing a node while a finger is down CANCELS that finger's gesture,
  and no release is ever delivered.** GTK rebuilds the widgets below an inserted
  child; the held widget is replaced, its gesture is cancelled, and
  `onPressRelease` — dutifully re-attached to the *new* widget by `.afterUpdate` —
  never fires, because that widget never saw a press. Anything driven by release
  (the auto-repeat) then runs forever. Measured: a conditional reset glyph sits
  above `−` in `lifeCounter`, so holding `−` from 40 made the glyph appear, rebuilt
  `−`, and drained the seat to −80 seconds after the finger lifted. Holding `+` was
  fine — it sits *above* the insertion point, so it is never rebuilt, which is why
  this hid for a while.
  **So: a layout's node structure must be constant; only strings may vary.** Draw
  absent children as empty text — and prefer to place optional things **beside**
  rather than above/below, because an empty label is zero-*width* but still a full
  line *high*: flanked, an always-present slot is free; stacked, it costs a blank
  line forever. `lifeCounter` flanks its total for exactly this reason, and a test
  pins the structure. This is the same rule as "never branch the view structure on state"
  below, but the failure here is a stuck gesture rather than a blank region.
  `HoldGate` also caps a repeat at 20 pulses so a lost release can't run away again.
- **A tap lands on a widget's REGION, not on its ink.** A `+` drawn 30px tall is a
  30px target no matter how much room its tile has. `WidgetView.region(minWidth:
  minHeight:)` — with `.touchTarget(_:)` and `.touchBand(_:)` sugar — gives a control
  a hit area independent of what it draws. `lifeCounter` uses it for the `+`/`−`
  bands (a quarter of the tile each) and the reset glyph (~11mm square).
- **Two greedy siblings do NOT split leftover space evenly.** Wrapping `+` and `−` in
  `maxHeight: .infinity` either side of a natural-height total gave a 116px top band
  and an 80px bottom one, quietly dragging the centred total 30px off centre. Use an
  explicit **minimum** and leave the surrounding `.spacer`s to centre, which is what
  `lifeCounter` does — that restores the glyphs to within ~3px of their old positions.
- **The dashboard only repaints on the 1s snapshot tick, so anything interactive
  must repaint itself.** An action mutates a service and then waits for the tick,
  which means feedback lags by up to a second — and anything repeating faster than
  1s appears to move in multiples. This is what made a correct +10 auto-repeat look
  like +20 (see §A). `main.swift`'s `onAction` now renders a fresh snapshot straight
  after `runner.perform`. **Verify interaction by capturing intermediate frames**, not
  the final value: the final value reconciles even when every frame before it is wrong.
- **No animation API at all.** Anything that moves is hand-stepped on a
  `Foundation.Timer` (`FrameTicker`) — not `DispatchQueue.main`, which GTK never
  drains. Any state change re-renders the whole view graph (~100 tile re-layouts
  per 8-frame animation), so ~20fps is the ceiling and moving a view across the
  screen leaves **ghost trails**. Animate a property of static views instead.
- **`defaultSize` doesn't fix the window size** — pin the root view's frame
  (`--window 1920x440` does this).
- **A root `GeometryReader` reports `0×0` on early passes** — treat as unknown.
- **A nested `GeometryReader` can report INFINITE size on probe passes.**
  `Int(proxy.size.width * x)` then fatal-traps ("Double value cannot be
  converted to Int") and takes the whole app down — this killed the kiosk on
  tap. Guard with `isFinite` and treat non-finite as size-unknown
  (`TileView`'s progress bar does this).
- **Never branch the VIEW STRUCTURE on state** — an `if`/`else` around two
  different modifier chains (in a `@ViewBuilder` or a `body`) blanked every
  board's content region, not just the affected tile. Switch *values* instead:
  same chain, `plain ? Color.clear : palette.surface`, radius 0 vs N
  (see `TileView.body` and `tileCorners(_:rounded:)`).
- **A GTK long press ALSO fires the tap, and the tap fires FIRST.**
  `onTapGesture(.primary)` is wired to `GestureClick::pressed` — it fires the
  instant the button goes down, not on release — and `GestureLongPress` fires
  later if the finger stays. So a hold delivers both actions, tap first. Measured:
  holding `+` moved life by 11 rather than 10. There is no press/release pair to
  reason from, so a tap on a hold-capable region has to be **deferred** ~550ms and
  cancelled if a hold follows (`HoldGate` in `DashboardUI/Support/`). Don't instead
  make the hold apply +9 to top up the tap, and don't suppress the tap *after* a
  hold: both assume an ordering that differs between GTK and AppKit.
- **Text is sized to its ink, not the font's advance.** Splitting a string per
  character therefore destroys side bearings (the clock's colon got overrun) —
  and even the separator-run split overran the colon once the joins were pulled
  tight. Superseded: the clock is now ONE run with real CSS letter-spacing (see
  above); don't split text for tracking at all.

## 4. Fonts

SF Pro is installed **on the Pi only**, at `~/.local/share/fonts/sf-pro` (47
faces, 308 MB, extracted from the user's own DMG). Neither the fonts nor the
config are in git, so a fresh kiosk install reverts to PibotoLt.

- The theme's `fontFamily` token reaches **the dev web renderer only**.
  SwiftCrossUI's `Font` has a single identifier — `.system` — and no way to name a
  family.
- `~/.config/gtk-4.0/settings.ini` (`gtk-font-name`) **does nothing** here. The
  working lever is user CSS: `~/.config/gtk-4.0/gtk.css` containing
  `* { font-family: "SF Pro Display"; }`.
- `Font.Weight(cssWeight:)` in `ThemeToSCUIPalette.swift` had `ultraLight`/`thin`
  swapped, which capped weight-100 headings at GTK CSS 300 (Light). Fixed; the
  theme's thin look depends on it.

## 5. Where the UI currently stands

- Panel is **1920×440** — an ultrawide strip, 1.5× the reference width but 0.55×
  its height. Type scales off **width**; vertical spacing off **height**
  (`ThemeToSCUIPalette.vertical*`). Never scale vertical spacing by the type scale.
- Three previews: **1 Board** (equal columns), **2 Wide clock** (1fr/1fr/3fr/2fr,
  temps · clock · music), **3 MTG**. Index 0 is what the kiosk boots into.
- Board columns are data (`BoardColumns` in `BoardScreen.swift`); adding an
  arrangement is a few lines.
- `WidgetLayout.centeredValue` (wide board's clock): title top-left, value +
  subtitle centred horizontally, top-aligned with neighbouring values. It carries
  several **measured** constants in `TileView.swift` — display size 2.6em, group
  lift 0.11em, tracking −0.05em at separators, and the tracked stack's
  height/push/lift (1.3 / 0.50 / 0.60em). They're tuned to this panel; re-measure
  if the size changes.

## 6. Open items

- **The mini's repo lives in `~/Documents`, inside iCloud sync.** Two commits
  failed with `.git/index.lock` write timeouts, and one of them left the index
  empty — the next commit deleted all 94 files and pushed it. Restored via
  `git read-tree <good-sha>` + commit (`4b187dc`). **Always `git status` before
  committing there, and pass explicit pathspecs.** Moving the clone out of
  `~/Documents` would remove the hazard.
- `~/.config/gtk-4.0/settings.ini` on the Pi is dead weight — safe to delete.
- Font install + `gtk.css` aren't reproducible; could be baked into
  `scripts/install-kiosk-pi.sh`.
- The dev web renderer still scales padding off width only (the native UI doesn't).

---

# Session addendum — 2026-08-06

## A. RESOLVED: hold auto-repeat double-steps on touch

**Symptom, reported on the real touchscreen:**

> first pulse +10, then +20 per pulse, and after letting go one more +10 lands

**Status: fixed.** The display now advances by exactly 10 per pulse.

**The root cause was never the gesture layer — it was the refresh rate.** The
dashboard re-rendered wholesale only on the runner's **1s snapshot tick**, while a
held button repeats every **0.45s**. Each repaint therefore absorbed two or three
correct +10 steps and drew them as a single jump. The stored value was right the whole
time; only the frames *between* ticks were wrong. That is precisely why the previous
session couldn't reproduce it — it measured the final value, which always reconciled.

**The fix** is in `App/DeskDashboardApp/main.swift`: `onAction` now calls
`renderer.render(runner.attachedWidgetSnapshots)` immediately after
`runner.perform(...)` instead of waiting for the tick. `SwiftCrossUIRenderer.onAction`
became a settable property (it was `init`-only) so the handler can repaint its own
renderer. This also stops a single tap from taking up to a second to appear.

**Measured on the panel, same synthetic hold, before and after** — cropped frames
every 0.3s with `grim -g "60,190 300x120"` while the button was held:

| | displayed sequence |
|---|---|
| before | 30 → 30 → 50 → 50 → 70 → 90 → 110 |
| after | 50 → 60 → 70 → 70 → 80 → 90 → … → 120 |

Both runs ended on the arithmetically correct total. **This symptom IS reproducible
with synthetic input** — contrary to what this doc said before — but only by capturing
*intermediate frames*. A final-value check will never show it. (A repeated value
between frames just means no pulse landed in that 0.3s gap.)

**Two real but unrelated defects were also fixed in `HoldGate.swift`** while chasing
this. They did not cause the doubling; keep them anyway:

1. `holdBegan` guarded with `repeater == nil`, but `tap()` calls the cancel path to
   recover from a missed release — so a press landing between two long presses could
   clear `repeater` and let a second repeat start.
2. `pressEnded()` never cancelled `pendingTap`, so a tap deferred during a hold fired
   0.55s *after* the finger lifted.

Both are now guarded by **elapsed time rather than gesture state**: an echo arrives
within milliseconds and no interleaved event can erase a timestamp. `pressEnded()`
cancels `pendingTap` **only** when a hold was actually running — cancelling
unconditionally means no tap ever fires, since a plain tap's release always beats its
own 0.55s deferral.

**What the instrumented run actually showed:** a touchscreen hold delivers **exactly
one** tap, one long press, one repeat per interval, and one release. There is no
duplicate long press and no emulated-pointer echo on this hardware, and
`gtk_gesture_single_set_touch_only` was never needed. The guards above are insurance,
not a workaround for something known to arrive.

**Two traps worth keeping:**

- **A one-shot `Timer` that has fired stays non-nil.** Testing `pendingTap != nil` to
  detect "a tap is already pending" swallows every tap after the first. Test
  `pendingTap?.isValid == true`.
- **`String(format:)` with `%@` is not dependable in swift-corelibs-foundation.**
  Pass only the `Double` through it and interpolate the rest.

**And the methodology lesson that cost the most time here:** `tap()` and `holdBegan()`
both call the same cancel path internally, so logging that path as "press ended"
made the log show a release a millisecond after every press and every hold. That
reads *exactly* like GTK double-delivering events for one finger, and I wrote a whole
guard against the phantom before noticing the file was logging itself. **Instrument
the external event separately from your own internal calls** — `pressEnded()` (the
GTK release) now logs `released`, and the private `cancelRepeat()` logs
`repeat cancelled`.

**Where the code is:**
- `Renderers/DashboardUI/Support/HoldGate.swift` — tap deferral, repeat timer, echo
  guards.
- `Renderers/DashboardUI/Support/PressReleaseGTK.swift` — release detection. GTK's
  primary `GestureClick` has a `released` signal SwiftCrossUI leaves unset; this
  fills it via `inspect(.afterUpdate)`.
- `Renderers/DashboardUI/Tiles/TileView.swift` — the `.tappable` case attaches
  `.onTapGesture`, `.onTapGesture(gesture: .longPress)` and `.onPressRelease`.
- `Renderers/DashboardUI/Renderer/DashboardModel.swift` — `perform(...)` / `endPress()`.

Design constraint to preserve: **do not** "fix" this by making the hold apply +9 to
top up the tap, and **do not** suppress the tap *after* a hold. Both assume a
gesture ordering that differs between GTK and AppKit. See the trap list in §3.

**A tap on a hold-capable region emits on RELEASE, not on a timer.** GTK's tap fires
on press, so a tap can't be told from a hold until the press resolves — but once
`onPressRelease` existed there was no reason to serve out the whole 550ms window on
every tap. That flat half-second of input lag was the "super laggy" report;
press-to-emit measured **2ms** after the change. `holdWindow` survives only as the
fallback for backends with no release signal (everything but GTK). `ActionBox`
guarantees one emit when release and the fallback race.

**Reading the gesture log.** `DD_UI_LOG=1` makes `HoldGate` print every event with a
`systemUptime` stamp. Note that the app is `exec`'d from `~/.config/sway/kiosk.conf`,
so its stderr is journalled under **`sway[pid]`, not the unit** — `journalctl -u
deskdashboard-ui` shows nothing. Grep the whole journal instead:

```bash
ssh willbarr@192.168.4.244 'journalctl --since "-5min" --no-pager | grep holdgate'
```

Set the variable with a drop-in (systemd env does reach the app through sway):

```bash
printf "[Service]\nEnvironment=DD_UI_LOG=1\n" | sudo tee \
  /etc/systemd/system/deskdashboard-ui.service.d/zzz-uilog.conf
sudo systemctl daemon-reload && sudo systemctl restart deskdashboard-ui
```

## B. What changed today

**One pattern applied everywhere: the shared type is a scaffold, each instance owns
a file, and instances stay reusable by name.**

| system | scaffold | instances |
|---|---|---|
| Themes | `DashboardKit/Theme/Theme.swift` (no values) | 4 files in `Theme/Themes/` |
| Widget layouts | `Widget/WidgetLayout.swift` (60 lines, was 255) | 13 files in `Widget/Layouts/` |
| Boards | `DashboardUI/Boards/BoardColumn.swift` | 5 files in `App/DeskDashboardApp/Dashboard/` |
| Services | 3 scaffolds (~50 lines each) | 6 files in `*/Services/` |
| Arrangements | — | `App/DeskDashboardApp/Dashboard/Arrangements.swift` |

`WidgetLayout` is a **struct with static members**, not an enum, so a layout is one
new file with zero scaffold edits; identity is its `id` string (tests pin uniqueness).
`WidgetView` and `TextRole` remain **enums on purpose** — `TileView` switches
exhaustively, so a new node type can't ship until every renderer draws it.

`Renderers/DashboardUI/` is foldered by role: `Renderer/` (no views), `Shell/`
(survives a screen switch), `Screens/`, `Tiles/`, `Boards/`, `Theme/`, `Support/`.
Translation files say so in their names (`ThemeToSCUIPalette`, `TextRoleToSCUIStyle`,
`TextToGTKTracking`). Every file has a `// Name.swift — one-line purpose` header.

**Production config now lives in the app, not the renderer.** `SwiftCrossUIRenderer`
takes `arrangements:`; `Composition.swift` declares `.theme(GreenBoardTheme())` and
it actually takes effect. There is no "preview mode" — the switcher only shows/hides
(`--kiosk`); `arrangements[selectedIndex]` always renders. Chrome geometry comes from
`DefaultTheme()` deliberately, so a content theme's caption size can't inflate the
header (it did: 13→18 grew the pill and stole tile height).

**Interactive widgets exist.** `WidgetView.tappable(action:hold:_:)` carries action
*names*; `InteractiveWidget.handle(action:environment:)` is opt-in like
`ServiceBackedWidget`; dispatch runs renderer → `onAction` sink → `main.swift` →
`DashboardRunner.perform` → `Dashboard` → widget → **service** → next snapshot.
State must live in a service (widgets are value types rebuilt each tick).

**MTG is now a board of widgets**, not a bespoke screen: `MTGScreen.swift`,
`Arrangement.Screen.mtg`, `model.isMTG` and `model.clockTime` are all gone. Four
`LifeCounterWidget`s + `TurnCounterWidget` share `InMemoryMTGGameService`. Life/turn
now **persist** across arrangement switches (the old view used local `@State`).
Converting it forced two capabilities into the open: `BoardRow` weights (the old
view let the clock take only its natural height) and `.fittedText` for the turn
number (a fixed display-size number could not fit any split of a 440px panel).

**Life tiles have a visible reset and a running change readout.** Tapping a life
total has always raised `life.reset`, but nothing said so. The total is now flanked
by a `↺` on the **left**, shown only when life ≠ 40, and the net change of the
adjustment in progress (`−30`) on the **right**, which expires ~3s after the last
tap. Both the glyph and the number raise the same reset action, so the big number
stays a reset target too.

Flanking, not stacking: both are always-present nodes (see §3), and an empty label
is zero-*width* but a full line *high*, so side-by-side makes "always present" free
where a row under the total cost every seat a permanently blank line. The two gaps
also sit either side of the number, so with both flankers empty it still lands dead
centre.

`MTGGameService` gained `var startingLife` and `recentLifeChange(for:)`. The change
readout lives in the service like everything else here — widgets are value types
rebuilt each tick — and **expires on read** against `systemUptime` rather than on a
timer, so nothing has to clear it. `InMemoryMTGGameService(changeWindow:)` is
injectable purely so a test can pin the expiry instead of sleeping.

Both readouts are drawn **unconditionally, as empty text when absent** — see the
gesture-cancellation trap in §3, which this tile is the worked example of. A
conditional glyph made holding `−` run away.

Two things measured on the panel while building it, both easy to trip over again:
- **The glyph's size is load-bearing.** At `.primary` (the `+`/`−` size) the tile's
  fixed content outgrew its band — seats showing the glyph lost their rounded bottom
  corner and pushed `−` to the panel edge. `.secondary` fits. `.badge`, which the turn
  tile uses, is caption-size — about a 4mm touch target here, too small for a finger.
  This tile has no vertical slack left; re-measure if the hero size or panel changes.
- **`↺` (U+21BA) renders only because SF Pro is installed on the Pi**, and per §4 the
  fonts aren't in git. A fresh kiosk install falls back to PibotoLt, where this glyph
  may be tofu. Check it after any font change.

**Header has two pills**: `ContainerMode` (`Auto`/`Tile`/`Bare`) overriding each
board's authored `containerless`, and the arrangement switcher (6 slots).
`Auto` is the default so nothing restyles at boot. NB: the gap between them is
trailing **padding** — a `Spacer(minLength:)` is flexible and expanded to fill the
row, shoving the toggle to the left margin and truncating the title.

## C. Housekeeping

- **174 tests pass** (`swift test`). The test target depends only on `DashboardKit` +
  `DeskDashboardWidgets` — keep it backend-free; renderer-only types (e.g.
  `ContainerMode`) are therefore verified on the panel instead.
- **Everything is uncommitted** on top of `cef0685`, and that commit is a **fork**:
  GitHub's `MacMiniDev` is at `69b1527`, which this history does not contain. The
  MacBook's `origin/*` refs are stale (it can't fetch) so its "ahead N" lies. See the
  hazard note in §1 before pushing anything.
- Pill slot centres at 1920×440, 6 arrangements: **1259 / 1356 / 1453 / 1550 / 1647 /
  1744 / 1841** for a 7-slot pill; with 6 slots the switcher spans x1306–1889 and the
  container toggle x1052–1277 (3 slots at 1090 / 1165 / 1240). Re-measure after any
  count change rather than trusting these.
- A restart resets the switcher to index 0, so **tap to the board you want before
  asserting anything** — I wasted a run screenshotting the wrong board.
- Tiles repaint on the 1s tick, and a deferred tap emits at +0.55s, so **allow ~3s
  before screenshotting** an interaction or you'll photograph the old value.
