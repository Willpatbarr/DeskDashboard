// DashboardRootView.swift — The shell: reserves the header band, dispatches to a screen.

import DashboardKit
import Foundation
import SwiftCrossUI

/// Root view: lays the widget tiles out from their `GridLayout` slots, the same
/// slots the dev web renderer feeds into CSS Grid. Tiles are grouped into rows
/// by `gridSlot.row` and ordered left-to-right by `gridSlot.column`.
///
/// The model is read once into `@State`; its `@Published` snapshots drive
/// re-renders as the observer ticks.
///
/// A `GeometryReader` wraps the whole board so the theme's size tokens can be
/// resolved against the *actual* window size. Nothing below sizes itself in raw
/// points: every font, gap and radius comes from the palette built here, so the
/// same dashboard fills a 1024×600 Pi panel and a 4K TV the same way.
struct DashboardRootView: View {
    @State private var model = DashboardLaunch.model
        ?? DashboardModel(theme: DarkDeskTheme())

    var body: some View {
        GeometryReader { proxy in
            let viewport = Viewport(width: proxy.size.width, height: proxy.size.height)
            let palette = model.palette(for: viewport)
            // Chrome geometry comes from the composition's theme, never the
            // selected preview's — otherwise the title and pill change size every
            // time you switch layout, since previews carry their own typography.
            let chrome = model.chromePalette(for: viewport)

            // Set DD_UI_LOG=1 to have the layout report its own geometry; the
            // panel can't be screenshotted, so this is how clipping gets
            // diagnosed. Logs once per distinct value, not per frame.
            // (bound to `_` so the ViewBuilder treats it as a declaration rather
            // than trying to make a View out of `Void`)
            let band = headerBandHeight(chrome, viewport)

            let _ = UILog.once("geometry", """
            LAYOUT viewport=\(Int(viewport.width))×\(Int(viewport.height)) \
            scale=\(palette.scale) vScale=\(palette.verticalScale) \
            pill=\(model.arrangements.count)×\(segmentWidth(chrome))=\
            \(model.arrangements.count * segmentWidth(chrome))w \
            ×\(pillHeight(chrome))h \
            band=\(Int(band)) content=\(Int(viewport.height - band)) \
            margins=\(palette.sectionMargin)/\(palette.verticalSectionMargin) \
            caption=\(palette.captionSize)
            """)

            Group {
                if let transition = model.transition {
                    // Mid-slide: the whole strip is the skeleton stage. Real
                    // content (and its taps) is out of the tree until the model
                    // completes the swap — a tap mid-sweep hits nothing.
                    SlideStage(
                        palette: palette,
                        width: viewport.width,
                        height: viewport.height,
                        from: model.bands(at: transition.fromIndex) ?? [],
                        to: model.bands(at: transition.toIndex) ?? [],
                        enteringFromRight: transition.enteringFromRight,
                        transitionKey: transition.key,
                        onFinished: { model.completeTransition() }
                    )
                } else if model.isFullscreen {
                    // Fullscreen arrangement: no header band at all — a slim rail
                    // (back pill + mini clock) beside the board, per the mockup.
                    HStack(spacing: 0) {
                        rail(palette, chrome)
                            .frame(width: railWidth(chrome), height: viewport.height)
                        // Slim leading margin: the rail already carries the gap,
                        // so the board's usual section margin would double up as
                        // dead space between the pill and the tile.
                        content(
                            palette,
                            height: viewport.height,
                            leadingMargin: chrome.widgetGap,
                            verticalMargin: chrome.verticalSectionMargin,
                            containerMode: .bare
                        )
                            .frame(
                                width: max(1, viewport.width - railWidth(chrome)),
                                height: viewport.height
                            )
                    }
                } else {
                    VStack(spacing: 0) {
                        // Fixed band at the top for the title + pill, then the widgets
                        // take whatever is left. Previously the header only asked for a
                        // `minHeight` while the content region was greedy
                        // (`maxHeight: .infinity`), so the VStack squeezed the header to
                        // its *text* height and the taller pill overflowed — which is what
                        // clipped the pill's bottom edge.
                        header(palette, chrome, viewport)
                            .frame(height: band)

                        // Exact height, not `maxHeight: .infinity`. Measured on the panel:
                        // a greedy child inside `.padding(.vertical:)` swallowed the
                        // bottom inset, so the tiles ran to y=439 of 440 — bleeding off
                        // the screen with their bottom corners cut. Sizing the region and
                        // its inset content explicitly leaves the margin intact.
                        content(palette, height: max(1, viewport.height - band))
                            .frame(width: viewport.width, height: max(1, viewport.height - band))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(background(palette, viewport))
            // A widget's modal, drawn over the WHOLE screen — the rail included.
            // Applied out here rather than inside the tile because that is the
            // difference the user sees: a scrim that stopped at the tile's edge
            // left the rail bright next to a greyed board.
            //
            // Same shape as `EditScrim`: a conditional `.overlay` whose first
            // child is a greedy `Color`, built INLINE. Extracting it into a
            // `View` struct is what makes composited chrome vanish on the GTK
            // backend, and an unconditional overlay would swallow every tap on
            // the dashboard.
            // Records where every press lands, in THIS view's coordinates.
            // Attached at the same point in the chain as the overlay below on
            // purpose: the probe reports relative to the widget it sits on, so
            // the two have to share one coordinate space or a popover placed
            // from the point would land somewhere else entirely.
            .touchPointProbe { model.recordTouch(x: $0, y: $1) }
            .overlay {
                if let modal = modal(palette) {
                    let scrim = Color(hex: modal.scrimHex) ?? palette.background
                    let side = sideInset(palette)
                    let top = Double(topInset(palette))
                    let panelHeight = max(1, viewport.height - top * 2)
                    // A popover only when the layout asked for one AND the
                    // backend actually reported a touch. No point means the
                    // centred branch, which is what `LayerAnchor.lastTouch`
                    // documents as its fallback — and what the AppKit dev build
                    // always gets.
                    let popover: (side: LayerSide, x: Double, y: Double)? = {
                        guard case let .lastTouch(side) = modal.anchor,
                              let point = model.lastTouchPoint
                        else { return nil }
                        return (side: side, x: point.x, y: point.y)
                    }()

                    if let popover {
                        // Placed by STRUT ARITHMETIC inside the tiling layout —
                        // the only positioning this backend has. There is no
                        // `.offset` or `.position` in SwiftCrossUI at all, so a
                        // fixed-size transparent spacer is how anything gets
                        // pushed anywhere (`.columns` does the same trick).
                        //
                        // Centred on the touch and clamped into the viewport
                        // using a conservative height estimate. Centring rather
                        // than top-aligning means a wrong estimate is wrong
                        // symmetrically instead of dropping the menu off an edge.
                        let menuHeight = popoverHeight(palette)
                        let menuWidth = popoverWidth(palette)
                        let menuTop = min(
                            max(0, popover.y - menuHeight / 2),
                            max(0, viewport.height - menuHeight)
                        )
                        let gap = Double(palette.widgetGap)

                        VStack(spacing: 0) {
                            dismissStrip(modal, scrim, width: viewport.width, height: menuTop)

                            HStack(spacing: 0) {
                                switch popover.side {
                                case .trailing:
                                    dismissStrip(
                                        modal, scrim,
                                        width: min(popover.x + gap, viewport.width),
                                        height: menuHeight
                                    )
                                    // Sized EXPLICITLY. The panel is a greedy
                                    // `TileView`, and a greedy view beside a
                                    // `Spacer` gets starved on this backend —
                                    // measured, the menu rendered at zero width
                                    // and simply never appeared.
                                    modal.panel
                                        .frame(width: menuWidth, height: menuHeight)
                                        .background(scrim)
                                    Spacer()
                                case .leading:
                                    // Pushed from the RIGHT, precisely so the
                                    // panel's own width never has to be known —
                                    // nothing here can measure it.
                                    Spacer()
                                    modal.panel
                                        .frame(width: menuWidth, height: menuHeight)
                                        .background(scrim)
                                    dismissStrip(
                                        modal, scrim,
                                        width: min(
                                            max(0, viewport.width - popover.x + gap),
                                            viewport.width
                                        ),
                                        height: menuHeight
                                    )
                                }
                            }
                            .frame(height: menuHeight)

                            dismissStrip(
                                modal, scrim,
                                width: viewport.width,
                                height: max(0, viewport.height - menuTop - menuHeight)
                            )
                        }
                    } else {

                    // Laid out as explicitly sized pieces that TILE the
                    // screen — no overlapping full-size siblings anywhere, and
                    // every region painted exactly ONCE.
                    //
                    // Both halves of that matter. A full-size scrim UNDER these
                    // strips double-painted the margins, so they came out
                    // visibly darker than the band showing between the panel's
                    // two cards; the panel carries its own scrim backdrop
                    // instead.
                    //
                    // And GTK picks the topmost widget under a tap without
                    // falling through to a sibling beneath, so a scrim layer
                    // covered by anything full-size (a `.padding` container, a
                    // greedy `HStack` holding the close button) stops receiving
                    // taps at all — exactly how tap-to-dismiss silently died
                    // twice. Tiling means every pixel belongs to one widget, and
                    // each one either dismisses or is the panel.
                    VStack(spacing: 0) {
                        dismissStrip(modal, scrim, width: viewport.width, height: top)

                        HStack(spacing: 0) {
                            dismissStrip(modal, scrim, width: side, height: panelHeight)

                            // Inset in LINE HEIGHTS — 5 either side, 3 top
                            // and bottom — so the panel reads as floating
                            // clear of the screen rather than as a bordered
                            // tile. The unit is a CAPTION line, not a body
                            // line: on a 440px strip three body lines top and
                            // bottom would eat 282 of them.
                            //
                            // Sized explicitly rather than padded, which also
                            // hands its `.columns` the definite width and
                            // height a GeometryReader wants.
                            modal.panel
                                .frame(
                                    width: max(1, viewport.width - side * 2),
                                    height: panelHeight
                                )
                                // Its own backdrop, so the gap between the
                                // two cards is scrim rather than board.
                                .background(scrim)

                            // The close control gets the whole right margin:
                            // its own button, clear of both cards, and a tap
                            // anywhere in that column closes.
                            VStack(spacing: 0) {
                                Spacer()
                                Text("✕")
                                    .font(.system(
                                        size: palette.headingSize,
                                        weight: .semibold
                                    ))
                                    .foregroundColor(palette.text)
                                Spacer()
                            }
                            .frame(width: side, height: panelHeight)
                            .background(scrim)
                            .onTapGesture { dismiss(modal) }
                        }

                        dismissStrip(modal, scrim, width: viewport.width, height: top)
                    }
                    }
                }
            }
        }
    }

    /// A conservative height for a `.lastTouch` popover, used only to keep it on
    /// screen. Two `menuRowHeight` rows plus the card's own padding and rule —
    /// `menuRowHeight` is shared with the layout that builds those rows, which is
    /// the only way the two can agree without measuring each other.
    private func popoverHeight(_ palette: ThemeToSCUIPalette) -> Double {
        (menuRowHeight * 2 + 24) * palette.scale
    }

    /// A `.lastTouch` popover's width. Chosen rather than measured: nothing here
    /// can ask the panel how wide it wants to be, and it MUST be given a
    /// definite frame — a greedy view beside a `Spacer` collapses on this
    /// backend. Wide enough for the longest row a two-item menu carries.
    private func popoverWidth(_ palette: ThemeToSCUIPalette) -> Double {
        140 * palette.scale
    }

    /// One band of the modal's margin: paints the scrim and dismisses on tap.
    /// Sized explicitly so it tiles with its neighbours rather than covering
    /// them — see the overlay for why that matters on GTK.
    private func dismissStrip(
        _ modal: Modal,
        _ scrim: Color,
        width: Double,
        height: Double
    ) -> some View {
        scrim
            .frame(width: max(1, width), height: max(1, height))
            .onTapGesture { dismiss(modal) }
    }

    /// Raises the modal's dismiss action, if it declared one.
    private func dismiss(_ modal: Modal) {
        guard let action = modal.dismiss else { return }
        model.perform(widgetID: modal.widgetID, action: action, cameFromHold: false)
    }

    /// The modal's inset, in caption line heights: 5 either side, 3 top and
    /// bottom. See the overlay for why the unit is a caption line.
    private func sideInset(_ palette: ThemeToSCUIPalette) -> Double {
        (palette.captionSize * 1.3 * 5).rounded()
    }

    private func topInset(_ palette: ThemeToSCUIPalette) -> Int {
        Int((palette.captionSize * 1.3 * 3).rounded())
    }

    /// The open modal, if any widget on the current board is raising one.
    ///
    /// Found by rebuilding each widget's `WidgetView` and looking for `.layered`
    /// at its root. That means `makeView` runs twice for the tile that owns it —
    /// once here, once in its own `TileView`. Affordable and deliberate: the
    /// alternative is state pushed up out of a view's body mid-render, and the
    /// tree is a pure function of the snapshot, so building it twice cannot
    /// disagree with itself.
    ///
    /// The panel comes back as a rendered `TileView` (bare: no surface, no
    /// padding, no title) so it goes through the very same interpreter the tiles
    /// do, and its taps route to the widget that raised it. `DashboardUI` never
    /// learns what any of it means — the dismiss action is just a name.
    private func modal(_ palette: ThemeToSCUIPalette) -> Modal? {
        // Never during a slide: the stage owns the screen, and the arrangement
        // underneath is mid-swap.
        guard model.transition == nil else { return nil }
        for row in modalCandidates {
            guard let snapshot = model.snapshots.first(where: { $0.id.rawValue == row.id }),
                  let content = snapshot.content
            else { continue }
            let layout = row.layout ?? snapshot.configuration.layout
            guard case let .layered(_, scrimHex, dismiss, anchor, panel) = layout.makeView(content)
            else { continue }
            return Modal(
                widgetID: row.id,
                scrimHex: scrimHex,
                dismiss: dismiss,
                anchor: anchor,
                panel: AnyView(
                    TileView(
                        snapshot: snapshot,
                        palette: palette,
                        // A layout of exactly this panel — the interpreter takes
                        // a `WidgetLayout`, and the panel is already built.
                        layoutOverride: WidgetLayout(id: "\(row.id).modal") { _ in panel },
                        containerless: true,
                        flush: true,
                        hidesTitle: true,
                        onAction: { action, isHold, isHoldable, holdRepeats in
                            model.perform(
                                widgetID: row.id,
                                action: action,
                                cameFromHold: isHold,
                                isHoldable: isHoldable,
                                holdRepeats: holdRepeats
                            )
                        },
                        onPressEnded: { model.endPress() }
                    )
                )
            )
        }
        return nil
    }

    /// Widgets that could be raising a modal: the current board's, or the plain
    /// tile grid's when there is no board.
    private var modalCandidates: [(id: String, layout: WidgetLayout?)] {
        if let bands = model.boardBands {
            return bands.flatMap { band in
                band.columns.flatMap { column in
                    column.rows.map { (id: $0.id, layout: Optional($0.layout)) }
                }
            }
        }
        return tiles.map { (id: $0.id.rawValue, layout: nil) }
    }

    /// One open modal: which widget raised it, how to dim behind it, what a tap
    /// on the scrim means, and the panel itself already rendered.
    private struct Modal {
        let widgetID: String
        let scrimHex: String
        let dismiss: String?
        /// Where the layer wants to sit — a full-screen modal or a popover
        /// beside the touch. See `LayerAnchor`.
        let anchor: LayerAnchor
        let panel: AnyView
    }

    // MARK: - Fullscreen rail

    /// Widest label any rail pill carries: `"..."`, the filter bucket for
    /// everything unclassified. Every pill in the rail is sized to it so the
    /// column reads as one stack rather than a wide pill above narrow ones —
    /// which costs the board ~2 glyphs of width, and it has them to spare.
    private static let railLabelWidth = 3

    /// The fullscreen rail's width: exactly one pill plus a hair of air — the
    /// widget gap, not the section margin, so the board gets the width back.
    private func railWidth(_ chrome: ThemeToSCUIPalette) -> Double {
        Double(
            segmentWidth(chrome, widestLabel: Self.railLabelWidth)
                + segmentInsets(chrome).track * 2
                + chrome.widgetGap * 2
        )
    }

    /// The left rail of a fullscreen arrangement: the `‹` back pill on top, then
    /// the mini clock — hours over minutes, per the mockup — and the board's
    /// filter pills pushed down to the bottom edge.
    private func rail(_ palette: ThemeToSCUIPalette, _ chrome: ThemeToSCUIPalette) -> some View {
        VStack(spacing: chrome.verticalWidgetGap) {
            railPill(
                palette, chrome,
                label: "‹",
                isOn: false,
                onTap: { model.exitFullscreen() }
            )

            // Body-size digits (caption read as an afterthought on the panel),
            // pushed clear of the pill by a section margin's worth of air.
            Text(railClock.hour)
                .font(.system(size: chrome.bodySize, weight: .semibold))
                .foregroundColor(palette.secondary)
                .padding(.top, chrome.verticalSectionMargin)
            Text(railClock.minute)
                .font(.system(size: chrome.bodySize, weight: .semibold))
                .foregroundColor(palette.secondary)

            Spacer()

            // Bottom edge, below the Spacer: filtering the board is a deliberate
            // act, so it sits as far as possible from the back pill you reach for
            // by reflex. Only drawn when the board on screen holds the widget the
            // pills address — see `DashboardModel.activeRailFilters`.
            if let bar = model.activeRailFilters {
                ForEach(bar.keys, id: \.self) { key in
                    railPill(
                        palette, chrome,
                        label: key,
                        isOn: model.railFilterSelection.contains(key),
                        onTap: { model.toggleRailFilter(key) }
                    )
                }
            }
        }
        .padding(.horizontal, chrome.widgetGap)
        .padding(.vertical, chrome.verticalSectionMargin)
    }

    /// One rail pill. Every pill in the rail is built through here so they share
    /// a width and, more importantly, the `.cornerRadius` + `.alwaysPillBorder`
    /// pair — that pair is what draws an `EditPill` at all on the GTK backend, so
    /// a hand-rolled copy that dropped one would render as nothing on the Pi
    /// while still working on AppKit.
    private func railPill(
        _ palette: ThemeToSCUIPalette,
        _ chrome: ThemeToSCUIPalette,
        label: String,
        isOn: Bool,
        onTap: @escaping () -> Void
    ) -> some View {
        EditPill(
            palette: palette,
            label: label,
            isOn: isOn,
            slotWidth: segmentWidth(chrome, widestLabel: Self.railLabelWidth),
            slotHeight: segmentHeight(chrome),
            trackInset: segmentInsets(chrome).track,
            fontSize: chrome.captionSize,
            onTap: onTap
        )
        .cornerRadius(max(0, pillHeight(chrome) / 2 - 1))
        .alwaysPillBorder(palette, radius: Double(max(0, pillHeight(chrome) / 2 - 1)))
    }

    /// The rail clock's digits, read from the clock WIDGET's snapshot rather than
    /// a timer of this view's own — the widget already ticks every second, and
    /// snapshots re-render this view anyway. Empty strings when the app has no
    /// clock widget (the rail just shows the back pill).
    private var railClock: (hour: String, minute: String) {
        let time = model.snapshots
            .first { $0.id.rawValue == "clock" }?
            .content?.primaryText ?? ""
        let parts = time.split(separator: ":").map(String.init)
        guard parts.count >= 2 else { return ("", "") }
        return (parts[0], parts[1])
    }

    /// The screen below the header: the interactive MTG mode, or the widget-tile
    /// grid for every other preview.
    ///
    /// - Parameter height: the region's exact height. Each branch is given a
    ///   definite inner size *before* its margins are added, so the margins
    ///   survive; with a greedy inner view the bottom inset was being dropped and
    ///   the tiles overran the bottom of the screen.
    /// - Parameter leadingMargin: overrides the content's left inset. The
    ///   fullscreen rail passes its small gap here — otherwise the board keeps
    ///   its full section margin, which read as dead space beside the rail.
    /// - Parameter verticalMargin: overrides the content's top/bottom insets.
    ///   Fullscreen passes the CHROME margin so the tile's top edge lines up
    ///   with the rail's back pill instead of the theme's deeper inset.
    /// - Parameter containerMode: overrides the header pill's container mode.
    ///   Fullscreen forces `.bare`, the way it forces the wallpaper off.
    @ViewBuilder private func content(
        _ palette: ThemeToSCUIPalette,
        height: Double,
        leadingMargin: Int? = nil,
        verticalMargin: Int? = nil,
        containerMode: ContainerMode? = nil
    ) -> some View {
        let vertical = verticalMargin ?? palette.verticalSectionMargin
        let inner = max(1, height - Double(vertical * 2))
        let leading = leadingMargin ?? palette.sectionMargin

        if let bands = model.boardBands {
            BoardScreen(
                palette: palette,
                snapshots: model.snapshots,
                bands: bands,
                containerMode: containerMode ?? model.containerMode,
                isEditing: model.isEditing,
                alignments: model.alignments,
                onSelectAlignment: { id, index in model.setAlignment(index, for: id) },
                onAction: { id, action, isHold, isHoldable, holdRepeats in
                    model.perform(
                        widgetID: id,
                        action: action,
                        cameFromHold: isHold,
                        isHoldable: isHoldable,
                        holdRepeats: holdRepeats
                    )
                },
                onPressEnded: { model.endPress() }
            )
                .frame(height: inner)
                .padding(.leading, leading)
                .padding(.trailing, palette.sectionMargin)
                .padding(.vertical, vertical)
        } else {
            HStack(spacing: palette.widgetGap) {
                ForEach(tiles, id: \.id.rawValue) { snapshot in
                    // No layout override: the tile grid is the honest default,
                    // so each widget draws with its own configured layout.
                    TileView(
                        snapshot: snapshot,
                        palette: palette,
                        alignment: model.alignment(for: snapshot.id.rawValue),
                        onAction: { action, isHold, isHoldable, holdRepeats in
                            model.perform(
                                widgetID: snapshot.id.rawValue,
                                action: action,
                                cameFromHold: isHold,
                                isHoldable: isHoldable,
                                holdRepeats: holdRepeats
                            )
                        }
                    )
                    .editScrim(
                        palette,
                        active: model.isEditing,
                        alignment: model.alignment(for: snapshot.id.rawValue) ?? .leading,
                        onSelectAlignment: { model.setAlignment($0, for: snapshot.id.rawValue) }
                    )
                    .tileCorners(palette)
                }
            }
            .frame(height: inner)
            .padding(.leading, leading)
            .padding(.trailing, palette.sectionMargin)
            .padding(.vertical, vertical)
        }
    }

    /// A top-to-bottom gradient when the palette defines one (the gradient-clock
    /// theme), otherwise the flat background color.
    ///
    /// An arrangement's `backgroundImage` outranks both — see `Arrangement` for
    /// why the wallpaper lives there rather than on the `Theme`. `DD_BG_IMAGE`
    /// overrides everything, for trying a file without a rebuild.
    @ViewBuilder private func background(
        _ palette: ThemeToSCUIPalette,
        _ viewport: Viewport
    ) -> some View {
        if model.showsWallpaper, let path = model.wallpaper {
            // Sized explicitly rather than left greedy: `.background` gives its
            // child the parent's proposal, and a `.resizable()` image with no
            // frame reports its intrinsic pixel size — which on a 1920-wide
            // wallpaper drags the whole window's layout out to the image.
            Image(URL(fileURLWithPath: path))
                .resizable()
                .frame(width: viewport.width, height: viewport.height)
        } else if let stops = palette.backgroundGradient {
            LinearGradient(
                colors: stops,
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            palette.background
        }
    }

    private func header(
        _ palette: ThemeToSCUIPalette,
        _ chrome: ThemeToSCUIPalette,
        _ viewport: Viewport
    ) -> some View {
        HStack {
            // The header's left slot used to be the arrangement name plus a
            // metrics readout; it's the Edit toggle now. Everything the readout
            // told you is still in the `DD_UI_LOG=1` geometry line above.
            editBar(palette, chrome)
                // Trailing PADDING, never a `Spacer` — a Spacer between two pills
                // is flexible and expands to eat the row (see the note further
                // down for the version of this that broke the header).
                .padding(.trailing, chrome.widgetGap)
                .layoutPriority(1)
            imageBar(palette, chrome)
                .layoutPriority(1)
            Spacer(minLength: 0)
            if model.showsSwitcher {
                // Container toggle first, arrangement switcher second — the
                // arrangement is the primary control, so it keeps the outer edge.
                //
                // The gap is trailing PADDING, not a `Spacer`: a Spacer is flexible
                // and `minLength` is only its floor, so one placed between the pills
                // expanded to fill the row — shoving the toggle against the left
                // margin and squeezing the title down to an ellipsis.
                hueBar(palette, chrome)
                    .padding(.trailing, chrome.widgetGap)
                    .layoutPriority(1)
                containerBar(palette, chrome)
                    .padding(.trailing, chrome.widgetGap)
                    .layoutPriority(1)
                previewBar(palette, chrome)
                    .layoutPriority(1)
            }
            // The `›` arrow into the fullscreen board. Outside the switcher
            // gate on purpose: `--kiosk` hides the arrangement pills, but the
            // fullscreen board must stay reachable on the kiosk.
            if model.fullscreenIndex != nil {
                arrowBar(palette, chrome)
                    .padding(.leading, chrome.widgetGap)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, chrome.sectionMargin)
        .padding(.vertical, chrome.verticalSectionMargin)
    }

    /// The header's `›` arrow: slides over to the fullscreen arrangement. Built
    /// like `editBar` so it reads as one of the same family of controls.
    private func arrowBar(_ palette: ThemeToSCUIPalette, _ chrome: ThemeToSCUIPalette) -> some View {
        EditPill(
            palette: palette,
            label: "›",
            isOn: false,
            slotWidth: segmentWidth(chrome, widestLabel: 1),
            slotHeight: segmentHeight(chrome),
            trackInset: segmentInsets(chrome).track,
            fontSize: chrome.captionSize,
            onTap: { model.enterFullscreen() }
        )
        .cornerRadius(max(0, pillHeight(chrome) / 2 - 1))
        .alwaysPillBorder(palette, radius: Double(max(0, pillHeight(chrome) / 2 - 1)))
    }

    /// A pill-shaped segmented switcher styled after the reference HTML toggle:
    /// a rounded translucent track with the active segment filled by the accent.
    /// Tap any segment to jump to that theme × layout combination.
    ///
    /// Radii are ~half the element height for a pill look. They must NOT be huge
    /// (e.g. CSS-style `999`): the AppKit backend sets `layer.cornerRadius`
    /// literally with `clipsToBounds`, and a radius larger than half the size
    /// collapses the clip mask, hiding the whole control (taps still land).
    /// Segment padding. Horizontal follows the type scale; vertical follows the
    /// height scale, so the pill doesn't eat the header's whole height on a short
    /// panel.
    private func segmentInsets(_ palette: ThemeToSCUIPalette) -> (vertical: Int, horizontal: Int, track: Int) {
        (
            // Generous enough that a digit's box (which always runs taller than
            // its font size) fits inside the slot — an undersized slot is what
            // clipped the bottom cap off the highlight circle.
            vertical: max(6, Int((11 * palette.verticalScale).rounded())),
            horizontal: Int((12 * palette.scale).rounded()),
            track: max(4, Int((6 * palette.verticalScale).rounded()))
        )
    }

    private func segmentHeight(_ palette: ThemeToSCUIPalette) -> Int {
        Int(palette.captionSize.rounded()) + segmentInsets(palette).vertical * 2
    }

    /// Every slot is the same width — sized to the WIDEST preview's short label,
    /// so the travelling glow's geometry stays uniform and taps stay predictable.
    ///
    /// This is affordable because the short labels are ≤5 characters and there
    /// are five of them (~500px total). History check before adding previews:
    /// with nine previews sized to the word "Compact" this control ran ~1320px
    /// and overflowed the Pi's 1920px header row, which is why it spent a while
    /// showing bare numbers. SwiftCrossUI exposes no text-measurement API, so
    /// this estimates ~0.62em per glyph at semibold.
    private func segmentWidth(_ palette: ThemeToSCUIPalette) -> Int {
        // Sized to the labels the pill actually SHOWS — fullscreen arrangements
        // are filtered out, so their (often longer) names don't widen every slot.
        segmentWidth(palette, widestLabel: model.switcherLabels.map(\.count).max() ?? 1)
    }

    /// Slot width for a pill whose widest label is `widestLabel` characters. Each
    /// pill sizes from its OWN labels — sharing one width would make the container
    /// toggle as wide as the arrangement switcher's longest name.
    private func segmentWidth(_ palette: ThemeToSCUIPalette, widestLabel: Int) -> Int {
        let glyphs = Double(max(1, widestLabel)) * palette.captionSize * 0.62
        return Int(glyphs.rounded()) + segmentInsets(palette).horizontal * 2
    }

    /// Height of the reserved top band: whatever the pill needs (or the title
    /// line, when the switcher is hidden) plus its vertical margins, capped at a
    /// third of the screen so the widgets always get the majority.
    ///
    /// Reserving this explicitly is what guarantees the pill's size, rather than
    /// leaving it to fight the greedy content region for space.
    private func headerBandHeight(_ palette: ThemeToSCUIPalette, _ viewport: Viewport) -> Double {
        // The Edit pill is in the row whether or not the switcher is, so the band
        // is pill-height either way — it can't shrink to a text line any more.
        let tallestElement = max(pillHeight(palette), Int(palette.captionSize * 1.3))
        // A few pixels of slack on top of the exact fit. Sized to the pill's
        // height plus its margins alone, the band left zero room, so any rounding
        // in the backend shaved the pill's bottom edge against the tile region.
        let breathingRoom = max(8, Int((12 * palette.verticalScale).rounded()))
        let wanted = Double(
            tallestElement + palette.verticalSectionMargin * 2 + breathingRoom
        )
        guard viewport.height > 0 else { return wanted }
        return min(wanted, viewport.height / 3)
    }

    /// The whole control's height, which the header row reserves explicitly.
    private func pillHeight(_ palette: ThemeToSCUIPalette) -> Int {
        SwitcherPill.height(
            slotHeight: segmentHeight(palette),
            trackInset: segmentInsets(palette).track
        )
    }

    /// The Edit toggle, sitting where the title used to. Same geometry chain as
    /// the switcher pills so it lines up with them across the row.
    private func editBar(_ palette: ThemeToSCUIPalette, _ chrome: ThemeToSCUIPalette) -> some View {
        EditPill(
            palette: palette,
            label: "Edit",
            isOn: model.isEditing,
            slotWidth: segmentWidth(chrome, widestLabel: 4),
            slotHeight: segmentHeight(chrome),
            trackInset: segmentInsets(chrome).track,
            fontSize: chrome.captionSize,
            onTap: { model.toggleEditing() }
        )
        .cornerRadius(max(0, pillHeight(chrome) / 2 - 1))
        // `alwaysPillBorder`, not `pillBorder`: with no track fill the outline is
        // the only thing drawing this control when it's off.
        .alwaysPillBorder(palette, radius: Double(max(0, pillHeight(chrome) / 2 - 1)))
    }

    /// The wallpaper toggle, built exactly like `editBar` so the two read as a
    /// pair of buttons rather than two one-off controls.
    private func imageBar(_ palette: ThemeToSCUIPalette, _ chrome: ThemeToSCUIPalette) -> some View {
        EditPill(
            palette: palette,
            label: "Image",
            isOn: model.showsBackgroundImage,
            slotWidth: segmentWidth(chrome, widestLabel: 5),
            slotHeight: segmentHeight(chrome),
            trackInset: segmentInsets(chrome).track,
            fontSize: chrome.captionSize,
            onTap: { model.toggleBackgroundImage() }
        )
        .cornerRadius(max(0, pillHeight(chrome) / 2 - 1))
        .alwaysPillBorder(palette, radius: Double(max(0, pillHeight(chrome) / 2 - 1)))
    }

    /// The container toggle: the same pill control as the arrangement switcher,
    /// with `ContainerMode`'s labels instead. Reusing it means the glide animation
    /// and every panel-measured inset come along for free.
    private func containerBar(_ palette: ThemeToSCUIPalette, _ chrome: ThemeToSCUIPalette) -> some View {
        let modes = ContainerMode.allCases
        return SwitcherPill(
            palette: palette,
            labels: modes.map(\.label),
            selected: modes.firstIndex(of: model.containerMode) ?? 0,
            slotWidth: segmentWidth(chrome, widestLabel: modes.map(\.label.count).max() ?? 4),
            slotHeight: segmentHeight(chrome),
            trackInset: segmentInsets(chrome).track,
            fontSize: chrome.captionSize,
            slideMilliseconds: DashboardLaunch.slideMilliseconds,
            onSelect: { model.selectContainerMode($0) }
        )
        .cornerRadius(max(0, pillHeight(chrome) / 2 - 1))
        .pillBorder(palette, radius: Double(max(0, pillHeight(chrome) / 2 - 1)))
    }

    /// Rotates the whole palette's hue. Built exactly like `containerBar` so it
    /// inherits the pill's geometry and every panel-measured inset.
    private func hueBar(_ palette: ThemeToSCUIPalette, _ chrome: ThemeToSCUIPalette) -> some View {
        let modes = HueMode.allCases
        return SwitcherPill(
            palette: palette,
            labels: modes.map(\.label),
            selected: modes.firstIndex(of: model.hueMode) ?? 0,
            slotWidth: segmentWidth(chrome, widestLabel: modes.map(\.label.count).max() ?? 5),
            slotHeight: segmentHeight(chrome),
            trackInset: segmentInsets(chrome).track,
            fontSize: chrome.captionSize,
            slideMilliseconds: DashboardLaunch.slideMilliseconds,
            onSelect: { model.selectHue($0) }
        )
        .cornerRadius(max(0, pillHeight(chrome) / 2 - 1))
        .pillBorder(palette, radius: Double(max(0, pillHeight(chrome) / 2 - 1)))
    }

    private func previewBar(_ palette: ThemeToSCUIPalette, _ chrome: ThemeToSCUIPalette) -> some View {
        SwitcherPill(
            palette: palette,
            // Filtered: fullscreen arrangements have no segment — the `›` arrow
            // is their way in — so labels, selection and taps all go through the
            // model's switcher-index mapping.
            labels: model.switcherLabels,
            selected: model.switcherSelected,
            slotWidth: segmentWidth(chrome),
            slotHeight: segmentHeight(chrome),
            trackInset: segmentInsets(chrome).track,
            fontSize: chrome.captionSize,
            slideMilliseconds: DashboardLaunch.slideMilliseconds,
            onSelect: { model.selectSwitcher($0) }
        )
        // The track's pill shape, applied HERE because corner radius only clips
        // a composited background when the parent applies it (same trap and
        // pattern as `tileCorners`). Half the height, minus one so it can never
        // exceed it — the AppKit backend hides a view whose radius beats its
        // size.
        .cornerRadius(max(0, pillHeight(chrome) / 2 - 1))
        .pillBorder(palette, radius: Double(max(0, pillHeight(chrome) / 2 - 1)))
    }

    // MARK: - Tile ordering

    /// Visible tiles laid out in a single inline row, ordered by their grid slot
    /// (row-major) so the arrangement stays stable across ticks. All tiles share
    /// the row width evenly (`TileView` expands to fill).
    private var tiles: [AttachedWidgetSnapshot] {
        model.snapshots
            .filter { $0.placement.visibility == .visible }
            .sorted {
                let l = $0.placement.gridSlot
                let r = $1.placement.gridSlot
                if (l?.row ?? 0) != (r?.row ?? 0) {
                    return (l?.row ?? 0) < (r?.row ?? 0)
                }
                return (l?.column ?? 0) < (r?.column ?? 0)
            }
    }
}
