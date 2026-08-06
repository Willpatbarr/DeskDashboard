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

`CONFIG=debug` matters: the kiosk unit runs `.build/debug/deskdashboard-ui`.
`JOBS=1` keeps the 4 GB Pi from OOM-ing.

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
