// DashboardModel.swift — Observable state: snapshots, selected arrangement, resolved palettes.

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
    /// Index into `arrangements`; set by `select(_:)` (a switcher tap).
    @Published private(set) var selectedIndex = 0
    /// Whether board tiles draw their chrome, overriding what each board authored.
    /// Driven by the header's second pill; `.authored` leaves boards as written.
    @Published private(set) var containerMode: ContainerMode = .authored

    /// Whether the header shows the arrangement switcher. Cosmetic only — it does
    /// NOT change what renders, which is `arrangements[selectedIndex]` either way.
    let showsSwitcher: Bool
    /// The app's arrangements, in switcher order. Index 0 is what the kiosk boots
    /// into. Supplied by the app, not owned here.
    let arrangements: [Arrangement]

    /// The dashboard's own configured theme (`Dashboard.configuration.theme`).
    ///
    /// Two jobs: it's the fallback for any arrangement that doesn't name a theme,
    /// and it always sizes the chrome. That second part is deliberate — an
    /// arrangement carrying different typography (caption 13/14/18) would
    /// otherwise resize the title and pill on every switch.
    private let dashboardTheme: any Theme

    /// Where taps go. Set by `SwiftCrossUIRenderer` from what the app supplied;
    /// nil means input is dropped, which is what a read-only dashboard wants.
    var onAction: ((String, String) -> Void)?

    /// Multiplied into the viewport-derived scale before sizes are resolved.
    /// Set from `--scale N` / `DD_UI_SCALE` so type can be dialed in on a real
    /// screen without a rebuild (a Pi build is slow). `1` means "as computed".
    let scaleMultiplier: Double

    init(
        theme: any Theme,
        snapshots: [AttachedWidgetSnapshot] = [],
        arrangements: [Arrangement] = [],
        showsSwitcher: Bool = false,
        scaleMultiplier: Double = 1
    ) {
        self.snapshots = snapshots
        self.showsSwitcher = showsSwitcher
        self.dashboardTheme = theme
        self.scaleMultiplier = scaleMultiplier > 0 ? scaleMultiplier : 1
        // With none supplied, the dashboard renders the way its composition
        // describes it: the configured theme, each widget's own layout, in the
        // tile grid. That is the honest default rather than a hidden catalogue.
        self.arrangements = arrangements.isEmpty
            ? [Arrangement(name: "Dashboard", short: "Main")]
            : arrangements
    }

    private var current: Arrangement { arrangements[selectedIndex] }

    /// The current preview's theme resolved for a window of `viewport` size —
    /// colors as authored, sizes scaled to the screen. Called from the root
    /// view's `GeometryReader`, so it re-resolves whenever the window resizes.
    func palette(for viewport: Viewport) -> ThemeToSCUIPalette {
        ThemeToSCUIPalette(
            theme: current.theme ?? dashboardTheme,
            viewport: viewport,
            scaleMultiplier: scaleMultiplier
        )
    }
    /// Palette for the app chrome (title line, switcher): geometry that must not
    /// move when the arrangement — or the app's theme — changes. Colours still
    /// come from `palette(for:)`, so the chrome matches what's on screen; only
    /// the sizes come from here.
    ///
    /// Deliberately the framework DEFAULT typography, not `dashboardTheme`. A
    /// content theme's caption size is tuned for tile legibility — `GreenBoardTheme`
    /// uses 18 against the default 13 — and sizing chrome from it inflated the pill
    /// and stole a band of height from the tiles the moment the composition's theme
    /// started counting for real.
    func chromePalette(for viewport: Viewport) -> ThemeToSCUIPalette {
        ThemeToSCUIPalette(
            theme: DefaultTheme(),
            viewport: viewport,
            scaleMultiplier: scaleMultiplier
        )
    }

    var arrangementName: String { current.name }
    /// The board's column spec when the current arrangement is a board, else `nil`.
    var boardColumns: [BoardColumn]? {
        if case let .board(columns) = current.screen { columns } else { nil }
    }


    /// Jump straight to an arrangement by index (a segment tap). Out-of-range is
    /// ignored. This is the hook a real layout switcher would drive too.
    ///
    /// Selection is instant; the pill owns its own highlight animation (see
    /// `PillAnimator`) so a slide never re-renders the tiles.
    func select(_ index: Int) {
        guard arrangements.indices.contains(index) else { return }
        selectedIndex = index
    }

    /// Drops the tap GTK sends along with a long press — see `HoldGate`.
    private let holdGate = HoldGate()

    /// Reports a tile's gesture onward. The renderer never handles it itself: the
    /// app owns the runner, so the app decides what an action means.
    ///
    /// `isHoldable` says whether this same region also has a hold action. If it
    /// does, the tap is held back briefly so a hold can cancel it — see `HoldGate`
    /// for why that can't be decided when the tap arrives.
    func perform(
        widgetID: String,
        action: String,
        cameFromHold: Bool,
        isHoldable: Bool = false
    ) {
        let emit: () -> Void = { [weak self] in self?.onAction?(widgetID, action) }
        if cameFromHold {
            holdGate.holdBegan(emit)
        } else {
            holdGate.tap(deferred: isHoldable, emit)
        }
    }

    /// The press ended — stop any hold that was repeating.
    func endPress() {
        holdGate.pressEnded()
    }

    /// Picks a container mode by switcher index (see `ContainerMode.allCases`).
    func selectContainerMode(_ index: Int) {
        let modes = ContainerMode.allCases
        guard modes.indices.contains(index) else { return }
        containerMode = modes[index]
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
