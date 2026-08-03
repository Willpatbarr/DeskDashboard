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

    /// Where the pill's highlight is drawn, as a *fractional* segment index.
    /// Equal to `previewIndex` at rest; during a tap it walks from the old index
    /// to the new one so the highlight slides instead of jumping.
    @Published private(set) var highlightPosition: Double = 0

    /// Frames in a highlight slide, at `Self.frameInterval` each — ~200ms total.
    /// Short on purpose: every frame re-renders the whole tree (all tiles, not
    /// just the pill), which is real work for the Pi's GTK backend.
    private static let slideFrames = 12
    private static let frameInterval = 0.016

    private let slideTicker = FrameTicker()
    private var slideFrame = 0
    private var slideFrom: Double = 0
    private var slideTo: Double = 0

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
            /// Curated four-tile board (clock, music, indoor, outdoor).
            case board
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

    /// The gradient-clock theme, shared by the clock and MTG previews.
    private static let gradientTheme = DarkDeskTheme(
        name: "Gradient",
        colors: .gradientClock,
        typography: .airy,
        shape: .rounded
    )

    /// The curated-board theme: gradient-clock colors, larger supporting text,
    /// rounded corners.
    private static let boardTheme = DarkDeskTheme(
        name: "Green Board",
        colors: .gradientClock,
        typography: .airyLegible,
        shape: .rounded
    )

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
        self.scaleMultiplier = scaleMultiplier > 0 ? scaleMultiplier : 1
        self.previews = [
            Preview(name: theme.name, short: "Real", theme: theme),
            Preview(name: "Dark · big number", short: "Big", theme: DarkDeskTheme(), layout: .bigNumber),
            Preview(name: "Dark · stat", short: "Stat", theme: DarkDeskTheme(), layout: .stat),
            Preview(name: "Light · standard", short: "Light",
                    theme: DarkDeskTheme(name: "Light", colors: .light), layout: .standard),
            Preview(name: "Light · compact", short: "Compact",
                    theme: DarkDeskTheme(name: "Light", colors: .light), layout: .compact),
            Preview(name: "Neon · minimal", short: "Neon",
                    theme: DarkDeskTheme(name: "Neon", colors: .neon), layout: .minimal),
            Preview(name: "Gradient · clock", short: "Clock",
                    theme: Self.gradientTheme, layout: .bigNumber),
            Preview(name: "Gradient · MTG", short: "MTG",
                    theme: Self.gradientTheme, screen: .mtg),
            Preview(name: "Green · board", short: "Board",
                    theme: Self.boardTheme, screen: .board),
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
    /// A layout forced on every tile for the current preview, or `nil`.
    var layoutOverride: WidgetLayout? { current.layout }
    var previewName: String { current.name }
    /// Whether the current preview is the interactive MTG mode.
    var isMTG: Bool { current.screen == .mtg }
    /// Whether the current preview is the curated four-tile board.
    var isBoard: Bool { current.screen == .board }

    /// The clock widget's latest time text, for the MTG mini-clock. Updates each
    /// tick as fresh snapshots arrive, so the MTG clock stays live.
    var clockTime: String {
        snapshots.first { $0.id.rawValue == "clock" }?.content?.primaryText ?? "--:--"
    }

    /// Jump straight to a preview by index (a segment tap). Out-of-range is
    /// ignored. This is the hook a real layout switcher would drive too.
    ///
    /// The content switches immediately; only the highlight is animated, so a tap
    /// never feels laggy even if the slide stutters.
    func select(_ index: Int) {
        guard previews.indices.contains(index), index != previewIndex else { return }

        slideFrom = highlightPosition
        slideTo = Double(index)
        slideFrame = 0
        previewIndex = index

        slideTicker.start(interval: Self.frameInterval) { [weak self] in
            self?.advanceSlide()
        }
    }

    /// One frame of the highlight slide. Eased out (cubic) so it decelerates into
    /// place rather than stopping dead.
    private func advanceSlide() {
        slideFrame += 1
        let t = min(1, Double(slideFrame) / Double(Self.slideFrames))
        let remaining = 1 - t
        let eased = 1 - remaining * remaining * remaining

        highlightPosition = slideFrom + (slideTo - slideFrom) * eased

        if t >= 1 {
            slideTicker.stop()
            highlightPosition = slideTo
        }
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
}
