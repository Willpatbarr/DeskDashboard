# Adding a new theme and widget layouts

A practical, repeatable checklist for building a new visual theme (colors,
type, spacing, shape) and the `WidgetLayout`s that go with it, then making them
selectable in the running app. Written from the "gradient clock" theme + MTG
work as the worked example.

## Mental model (read this first)

The look of a tile is produced by three separable pieces:

1. **Theme** — *tokens only*: colors, typography, spacing, shape. No pixels tied
   to any widget. Lives in `DashboardKit` (backend-agnostic).
2. **WidgetLayout** — *structure only*: how a widget's `WidgetContent`
   (title / primary / secondary / accessory / metadata) is arranged into a
   semantic tree (`WidgetView`) of stacks, text-with-**roles**, badges, spacers.
   No fonts or colors. Also in `DashboardKit`.
3. **Renderer** — resolves the two together. The SwiftCrossUI renderer
   (`TileView`) maps each **role** (`.hero`, `.title`, …) to a concrete
   font + color pulled from the active theme's `ThemePalette`.

So: **layout says "this is the hero value"; theme says "hero = 70pt thin,
primary color"; the renderer draws it.** A new layout works in every renderer
for free; a new theme restyles every layout for free.

```
WidgetContent ──(WidgetLayout)──▶ WidgetView (roles) ──(TileView + ThemePalette)──▶ pixels
                                                              ▲
                                                          Theme tokens
```

### Files you'll touch

| Concern | File |
| --- | --- |
| Theme tokens (colors/type/spacing/shape) | `Sources/Framework/DashboardKit/Theme/Theme.swift` |
| Layout structures | `Sources/Framework/DashboardKit/Widget/WidgetLayout.swift` |
| Semantic tree + roles (only if adding a role) | `Sources/Framework/DashboardKit/Widget/WidgetView.swift` |
| Token → SwiftCrossUI value | `Sources/Renderers/DashboardUI/ThemePalette.swift` |
| Role → concrete font/color | `Sources/Renderers/DashboardUI/TileView.swift` |
| Make it selectable (pill switcher) | `Sources/Renderers/DashboardUI/DashboardModel.swift` |
| Per-widget default layout | `Sources/App/DeskDashboardComposition/Composition.swift` |

> The theme/layout switcher and any interactive screens live **only** in the
> native `deskdashboard-ui` app. The `deskdashboard-dev` web renderer styles a
> single theme into its own CSS and does **not** use `WidgetLayout` — don't
> expect new layouts to show there.

---

## Part A — Add a theme

All theme tokens are plain value types with named static presets. A "theme" is a
`DarkDeskTheme(name:colors:typography:spacing:shape:...)` built from them.

### 1. Colors

In `Theme.swift`, add a `ThemeColors` preset next to `.darkDesk` / `.light` /
`.neon`:

```swift
public static let myTheme = Self(
    background: "#0F2018",     // flat fallback background
    surface:    "#05120B47",  // tile fill (8-digit hex = has alpha)
    primary:    "#FFFFFF",     // main values
    secondary:  "#8FD79A",     // titles / labels
    accent:     "#8FD79A",     // badges, highlights
    text:       "#FFFFFF",     // secondary lines
    mutedText:  "#6F9E78",     // metadata / fine print
    backgroundGradient: ["#193326", "#0F2018", "#08110D"]  // optional, top→bottom
)
```

- Colors are `#RGB`, `#RGBA`, `#RRGGBB`, or `#RRGGBBAA` strings (the palette
  parser handles alpha — use it for translucent panels).
- `backgroundGradient` is optional. With ≥2 stops the renderer paints a
  top-to-bottom `LinearGradient` behind everything; otherwise it uses the flat
  `background`.

### 2. Typography and shape (optional presets)

Add presets if the defaults don't fit. Example (the airy clock look):

```swift
// in ThemeTypography
public static let airy = Self(
    fontFamily: "SF Pro",
    headingSize: 44, bodySize: 18, captionSize: 14,
    headingWeight: 100,   // CSS-style 100–900; mapped to nearest named weight
    bodyWeight: 300
)

// in ThemeShape
public static let rounded = Self(cornerRadius: 28, borderWidth: 1, elevation: 2)
```

`headingSize` is the base; `TileView` derives the `.hero` size from it
(currently `headingSize * 1.6`).

### 3. (Only if you add a brand-new token)

If you add a field to `ThemeColors`/`ThemeTypography`/etc. (like
`backgroundGradient` was added), you must also:

- give it a default in the token's `init` (keeps existing call sites compiling),
- resolve it in `ThemePalette` (hex → `Color`, number → value, …),
- consume it in the view (`DashboardRootView`/`TileView`).

If you're only using existing tokens, skip this — `ThemePalette` already maps
everything.

---

## Part B — Add widget layouts

A `WidgetLayout` is a pure function `WidgetContent -> WidgetView`. Add a case and
a builder in `WidgetLayout.swift`.

### 1. The vocabulary you build with

`WidgetView` nodes:

- `.text(String, role:)` — text in a semantic **role**
- `.badge(String)` — a small pill (accent-colored)
- `.spacer` — flexible space that pushes siblings apart
- `.stack(.horizontal|.vertical, spacing:, [children])`

`TextRole` (each maps to a font+color in `TileView.style(for:)`):

| Role | Meaning |
| --- | --- |
| `.title` | small uppercase label |
| `.hero` | oversized display value (clock/big number) |
| `.primary` | main value at heading size |
| `.secondary` | supporting line |
| `.caption` | de-emphasized fine print / metadata |

### 2. Add the case + builder

```swift
public enum WidgetLayout: Sendable, Equatable {
    case standard, bigNumber, stat, compact, minimal
    case myLayout   // ← new

    public func makeView(_ content: WidgetContent) -> WidgetView {
        switch self {
        ...
        case .myLayout: Self.makeMyLayout(content)
        }
    }

    private static func makeMyLayout(_ content: WidgetContent) -> WidgetView {
        var children: [WidgetView] = []
        if let title = content.title { children.append(.text(title, role: .title)) }
        children.append(.text(content.primaryText, role: .hero))
        if let secondary = content.secondaryText {
            children.append(.text(secondary, role: .secondary))
        }
        return .stack(.vertical, spacing: 4, children)
    }
}
```

Keep it backend-agnostic — no sizes/colors here. If you need a genuinely new
visual treatment (say a "display" role bigger than `.hero`), add a case to
`TextRole` in `WidgetView.swift` and handle it in `TileView.style(for:)`.

### 3. (Optional) an interactive / full-screen mode

Ordinary layouts are read-only tiles. If you want something interactive (like
MTG mode's tap counters), that can't be expressed by `WidgetView` (it has no
buttons/state). Build it as a dedicated SwiftCrossUI view (see `MTGModeView.swift`)
with local `@State`, and branch to it in `DashboardRootView.content`. Use
`.onTapGesture` on styled `Text`/stacks for full visual control.

---

## Part C — Make it selectable and/or default

### Add it to the pill switcher

In `DashboardModel.swift`, add a `Preview` to the `previews` array. It appears as
a segment in the top-right switcher (shown by default; `--kiosk` hides it):

```swift
Preview(name: "My theme · big",       // full name (header text)
        short: "Mine",                 // pill segment label (keep short)
        theme: DarkDeskTheme(
            name: "MyTheme",
            colors: .myTheme,
            typography: .airy,
            shape: .rounded
        ),
        layout: .myLayout),            // forces this layout on every tile
```

- `layout:` forces one layout on all tiles for that preview; omit (`nil`) to let
  each widget keep its own layout.
- `mtg: true` swaps the whole screen for the interactive MTG view instead of
  tiles (template for other full-screen modes).

### (Optional) make a widget default to a layout

Independent of the switcher, a widget can pick its layout in the composition:

```swift
// Sources/App/DeskDashboardComposition/Composition.swift
ClockWidget().id("clock").title("Clock").layout(.myLayout)
```

---

## Build, run, verify

Native app (this is where themes/layouts/switcher live):

```bash
swift build -c release --product deskdashboard-ui
.build/release/deskdashboard-ui          # switcher visible by default
```

Tap your new segment in the top-right pill. `--kiosk` hides the switcher for the
fixed Pi display.

Deploy to the Pi (builds natively there — can't cross-compile the GTK UI):

```bash
# on the Pi, in the repo clone
git pull --ff-only origin MacMiniDev
CONFIG=debug JOBS=1 bash scripts/build-ui-pi.sh   # debug + 1 job for 4 GB RAM
sudo systemctl restart deskdashboard-ui
```

---

## Gotchas (learned the hard way)

- **`cornerRadius` doesn't clamp.** The AppKit backend sets `layer.cornerRadius`
  literally with `clipsToBounds`. A value larger than half the element's
  height/width (e.g. a CSS-style `999` for a "pill") collapses the clip mask and
  the whole control renders **invisible** — while a wrapping `.onTapGesture`
  still works, so it "functions but isn't there." Use ~half the element height.
- **Wrong product.** The switcher/layouts are in `deskdashboard-ui`, not
  `deskdashboard-dev` (web). Rebuild and run the UI product.
- **Rebuild actually happened.** After editing, confirm the `DashboardUI` files
  recompiled in the build output; run the freshly built binary path.
- **Translucent panels, not blur.** SwiftCrossUI has no `backdrop-filter`; fake
  glassy panels with an alpha in the `surface` color, not a blur.
- **Interactive controls need real views.** `WidgetLayout`/`WidgetView` is
  read-only. Anything tappable/stateful is a hand-written SwiftCrossUI view.
