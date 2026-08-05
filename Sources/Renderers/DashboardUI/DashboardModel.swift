import DashboardKit
import SwiftCrossUI

/// Observable state backing the SwiftCrossUI dashboard.
///
/// The renderer pushes fresh widget snapshots into `snapshots` on every tick;
/// SwiftCrossUI observes the `@Published` change (via the view's `@State`) and
/// re-renders. This is the real-UI analogue of the dev renderers' `render(_:)`
/// call — same input (`[AttachedWidgetSnapshot]`), different sink.
final class DashboardModel: ObservableObject {
    @Published var snapshots: [AttachedWidgetSnapshot]
    /// Index into `previews`; advanced by `nextPreview()` (the toggle button).
    @Published private(set) var previewIndex = 0

    /// Whether to show the preview toggle button (the `--preview` flag).
    let showsPreviewControls: Bool
    /// Curated theme × layout combinations to cycle through. Index 0 is the
    /// real configuration (the composition's theme, each widget's own layout).
    let previews: [Preview]

    struct Preview {
        let name: String
        /// Short label shown in the pill selector segment.
        let short: String
        let theme: any Theme
        /// A layout to force on every tile, or `nil` to use each widget's own.
        let layout: WidgetLayout?
        /// A dedicated full-screen mode that replaces the widget-tile grid, or
        /// `nil` for the ordinary tile layout.
        let screen: Screen?

        /// Full-screen modes that swap out the normal tile grid.
        enum Screen: Equatable {
            /// Interactive Magic: The Gathering life/turn tracker.
            case mtg
            /// Curated single-row board with proportional column widths.
            case board([CuratedGreenView.Column])
        }

        init(
            name: String,
            short: String,
            theme: any Theme,
            layout: WidgetLayout? = nil,
            screen: Screen? = nil
        ) {
            self.name = name
            self.short = short
            self.theme = theme
            self.layout = layout
            self.screen = screen
        }
    }

    // Themes are defined in DashboardKit (`Theme/Themes/`), one file each, so a
    // new one is a new file there plus a `Preview` entry below — not an edit
    // here *and* in the theme scaffold.
    private static let gradientTheme = GradientClockTheme()
    private static let boardTheme = GreenBoardTheme()

    /// The composition's real theme, kept aside from `previews` so the app chrome
    /// (title line, switcher pill) can size itself from something that does *not*
    /// change when you pick a preview. Previews carry their own typography
    /// (caption 13/14/18), so chrome sized from the selected preview's palette
    /// visibly resized itself on every switch.
    private let chromeTheme: any Theme

    /// Multiplied into the viewport-derived scale before sizes are resolved.
    /// Set from `--scale N` / `DD_UI_SCALE` so type can be dialed in on a real
    /// screen without a rebuild (a Pi build is slow). `1` means "as computed".
    let scaleMultiplier: Double

    init(
        theme: any Theme,
        snapshots: [AttachedWidgetSnapshot] = [],
        showsPreviewControls: Bool = false,
        scaleMultiplier: Double = 1
    ) {
        self.snapshots = snapshots
        self.showsPreviewControls = showsPreviewControls
        self.chromeTheme = theme
        self.scaleMultiplier = scaleMultiplier > 0 ? scaleMultiplier : 1
        // Index 0 is what the kiosk shows at boot, so the everyday board leads.
        self.previews = [
            Preview(name: "Green · board", short: "Board",
                    theme: Self.boardTheme, screen: .board(BoardColumns.equalWidths)),
            Preview(name: "Green · wide clock", short: "Wide",
                    theme: Self.boardTheme, screen: .board(BoardColumns.wideClock)),
            Preview(name: "Green · focus", short: "Focus",
                    theme: Self.boardTheme, screen: .board(BoardColumns.focus)),
            Preview(name: "Green · focus flipped", short: "Flip",
                    theme: Self.boardTheme, screen: .board(BoardColumns.focusFlipped)),
            Preview(name: "Gradient · MTG", short: "MTG",
                    theme: Self.gradientTheme, screen: .mtg),
        ]
    }

    private var current: Preview { previews[previewIndex] }

    /// The current preview's theme resolved for a window of `viewport` size —
    /// colors as authored, sizes scaled to the screen. Called from the root
    /// view's `GeometryReader`, so it re-resolves whenever the window resizes.
    func palette(for viewport: Viewport) -> ThemePalette {
        ThemePalette(
            theme: current.theme,
            viewport: viewport,
            scaleMultiplier: scaleMultiplier
        )
    }
    /// Palette for the app chrome: sizes that stay put across preview switches.
    /// Colours still come from `palette(for:)` so the chrome matches the theme on
    /// screen — it's only the geometry that must not move.
    func chromePalette(for viewport: Viewport) -> ThemePalette {
        ThemePalette(
            theme: chromeTheme,
            viewport: viewport,
            scaleMultiplier: scaleMultiplier
        )
    }

    /// A layout forced on every tile for the current preview, or `nil`.
    var layoutOverride: WidgetLayout? { current.layout }
    var previewName: String { current.name }
    /// Whether the current preview is the interactive MTG mode.
    var isMTG: Bool { current.screen == .mtg }
    /// The board's column spec when the current preview is a board, else `nil`.
    var boardColumns: [CuratedGreenView.Column]? {
        if case let .board(columns) = current.screen { columns } else { nil }
    }

    /// The clock widget's latest time text, for the MTG mini-clock. Updates each
    /// tick as fresh snapshots arrive, so the MTG clock stays live.
    var clockTime: String {
        snapshots.first { $0.id.rawValue == "clock" }?.content?.primaryText ?? "--:--"
    }

    /// Jump straight to a preview by index (a segment tap). Out-of-range is
    /// ignored. This is the hook a real layout switcher would drive too.
    ///
    /// Selection is instant; the pill owns its own highlight animation (see
    /// `PillAnimator`) so a slide never re-renders the tiles.
    func select(_ index: Int) {
        guard previews.indices.contains(index) else { return }
        previewIndex = index
    }
}

/// Hand-off point between the app-composition code and the SwiftCrossUI `App`.
///
/// `App.main()` constructs the app via a no-argument `init()`, so there's no way
/// to pass the model in directly. The renderer stashes the model here just
/// before launching; `DashboardRootView` reads it once into its `@State`.
enum DashboardLaunch {
    nonisolated(unsafe) static var model: DashboardModel?

    /// The window's opening size. Defaults to the theme reference canvas, so an
    /// unconfigured launch starts at scale 1×. Override with `--window 1920x440`
    /// to reproduce a target panel's geometry — the Pi's strip display is a very
    /// different shape from a Mac window, and that shape is what breaks layouts.
    nonisolated(unsafe) static var windowSize: (width: Int, height: Int) = (1280, 800)

    /// Set only when `--window` was passed explicitly. `defaultSize` alone is not
    /// enough: it seeds the window's initial rect, then SwiftCrossUI resizes the
    /// window to its content's ideal size, and this dashboard's root fills space
    /// flexibly — so the window snapped back to its content size (~1329×350) and
    /// the flag silently did nothing. Pinning the *root view* to the requested
    /// frame makes the content's ideal size the requested size.
    nonisolated(unsafe) static var forcedWindowSize: (width: Int, height: Int)?

    /// Total duration of the pill's highlight slide, in milliseconds. `0` turns
    /// the animation off (instant jump). Set from `DD_UI_SLIDE_MS`, so a display
    /// that renders frames too slowly can be tuned or opted out without a rebuild
    /// — which matters when the target is a Pi and each build is minutes.
    nonisolated(unsafe) static var slideMilliseconds: Double = 300

    /// Seconds between hand-stepped animation frames. Same reasoning as
    /// `slideMilliseconds`: set from `DD_UI_FRAME_MS` so a display's real frame
    /// budget can be found by sweeping the value on the device instead of
    /// rebuilding, with `DD_UI_LOG=1` reporting what was achieved.
    ///
    /// 20ms (50fps) is **measured**, not guessed: asking the Pi for 16ms over a
    /// 93-frame run delivered a 19ms mean (≈52fps), so 20ms sits inside the
    /// panel's real capability and paces evenly instead of relying on the
    /// timer's catch-up frames (that run's min was 4ms). Do not read the old
    /// 50ms/20fps figure in git history as a panel limit — it was measured when
    /// each frame re-laid-out every tile.
    ///
    /// Worst frame in that run was 172ms: a snapshot tick (the dashboard
    /// re-renders wholesale every second) can still stall one frame mid-slide.
    nonisolated(unsafe) static var frameSeconds: Double = 1.0 / 50.0
}
