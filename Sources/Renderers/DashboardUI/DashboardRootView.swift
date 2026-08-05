import DashboardKit
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
            pill=\(model.previews.count)×\(segmentWidth(chrome))=\
            \(model.previews.count * segmentWidth(chrome))w \
            ×\(pillHeight(chrome))h \
            band=\(Int(band)) content=\(Int(viewport.height - band)) \
            margins=\(palette.sectionMargin)/\(palette.verticalSectionMargin) \
            caption=\(palette.captionSize)
            """)

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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(background(palette))
        }
    }

    /// The screen below the header: the interactive MTG mode, or the widget-tile
    /// grid for every other preview.
    ///
    /// - Parameter height: the region's exact height. Each branch is given a
    ///   definite inner size *before* its margins are added, so the margins
    ///   survive; with a greedy inner view the bottom inset was being dropped and
    ///   the tiles overran the bottom of the screen.
    @ViewBuilder private func content(
        _ palette: ThemePalette,
        height: Double
    ) -> some View {
        let inner = max(1, height - Double(palette.verticalSectionMargin * 2))

        if model.isMTG {
            MTGModeView(palette: palette, time: model.clockTime)
                .frame(height: inner)
                .padding(.horizontal, palette.sectionMargin)
                .padding(.vertical, palette.verticalSectionMargin)
        } else if let columns = model.boardColumns {
            CuratedGreenView(palette: palette, snapshots: model.snapshots, columns: columns)
                .frame(height: inner)
                .padding(.horizontal, palette.sectionMargin)
                .padding(.vertical, palette.verticalSectionMargin)
        } else {
            HStack(spacing: palette.widgetGap) {
                ForEach(tiles, id: \.id.rawValue) { snapshot in
                    TileView(
                        snapshot: snapshot,
                        palette: palette,
                        layoutOverride: model.layoutOverride
                    )
                    .tileCorners(palette)
                }
            }
            .frame(height: inner)
            .padding(.horizontal, palette.sectionMargin)
            .padding(.vertical, palette.verticalSectionMargin)
        }
    }

    /// A top-to-bottom gradient when the palette defines one (the gradient-clock
    /// theme), otherwise the flat background color.
    @ViewBuilder private func background(_ palette: ThemePalette) -> some View {
        if let stops = palette.backgroundGradient {
            LinearGradient(
                colors: stops,
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            palette.background
        }
    }

    /// `1920×1080 @1.35×` — the viewport the layout system actually reported and
    /// the scale derived from it. Shown next to the preview name whenever the
    /// switcher is visible, so what the sizing is doing is verifiable *on the
    /// screen in question* rather than inferred from logs.
    private func metricsReadout(_ palette: ThemePalette, _ viewport: Viewport) -> String {
        let w = Int(viewport.width.rounded())
        let h = Int(viewport.height.rounded())
        let scale = (palette.scale * 100).rounded() / 100
        return "\(w)×\(h) @\(scale)×"
    }

    private func header(
        _ palette: ThemePalette,
        _ chrome: ThemePalette,
        _ viewport: Viewport
    ) -> some View {
        HStack {
            // With the switcher visible the pill needs most of the row (nine
            // uniform slots ≈ 1320px at 1.5×), so the "DeskDashboard" prefix is
            // dropped — on a kiosk the app's identity isn't in question, and
            // keeping it overflowed 1920px.
            Text(
                model.showsPreviewControls
                    ? "\(model.previewName) · \(metricsReadout(palette, viewport))"
                    : "DeskDashboard · \(model.previewName)"
            )
                .font(.system(size: chrome.captionSize, weight: palette.bodyWeight))
                .foregroundColor(palette.secondary)
                .lineLimit(1)
                // The pill wins any contest for the row's width: it has a fixed
                // size and gets clipped if squeezed, whereas the title can simply
                // truncate. (Left-edge clipping came from the pill losing this.)
                .layoutPriority(-1)
            Spacer(minLength: 0)
            if model.showsPreviewControls {
                previewBar(palette, chrome)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, chrome.sectionMargin)
        .padding(.vertical, chrome.verticalSectionMargin)
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
    private func segmentInsets(_ palette: ThemePalette) -> (vertical: Int, horizontal: Int, track: Int) {
        (
            // Generous enough that a digit's box (which always runs taller than
            // its font size) fits inside the slot — an undersized slot is what
            // clipped the bottom cap off the highlight circle.
            vertical: max(6, Int((11 * palette.verticalScale).rounded())),
            horizontal: Int((12 * palette.scale).rounded()),
            track: max(4, Int((6 * palette.verticalScale).rounded()))
        )
    }

    private func segmentHeight(_ palette: ThemePalette) -> Int {
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
    private func segmentWidth(_ palette: ThemePalette) -> Int {
        let widest = model.previews.map(\.short.count).max() ?? 1
        let glyphs = Double(widest) * palette.captionSize * 0.62
        return Int(glyphs.rounded()) + segmentInsets(palette).horizontal * 2
    }

    /// Height of the reserved top band: whatever the pill needs (or the title
    /// line, when the switcher is hidden) plus its vertical margins, capped at a
    /// third of the screen so the widgets always get the majority.
    ///
    /// Reserving this explicitly is what guarantees the pill's size, rather than
    /// leaving it to fight the greedy content region for space.
    private func headerBandHeight(_ palette: ThemePalette, _ viewport: Viewport) -> Double {
        let tallestElement = model.showsPreviewControls
            ? max(pillHeight(palette), Int(palette.captionSize * 1.3))
            : Int(palette.captionSize * 1.3)
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
    private func pillHeight(_ palette: ThemePalette) -> Int {
        PreviewPill.height(
            slotHeight: segmentHeight(palette),
            trackInset: segmentInsets(palette).track
        )
    }

    private func previewBar(_ palette: ThemePalette, _ chrome: ThemePalette) -> some View {
        PreviewPill(
            palette: palette,
            labels: model.previews.map(\.short),
            selected: model.previewIndex,
            slotWidth: segmentWidth(chrome),
            slotHeight: segmentHeight(chrome),
            trackInset: segmentInsets(chrome).track,
            fontSize: chrome.captionSize,
            slideMilliseconds: DashboardLaunch.slideMilliseconds,
            onSelect: { model.select($0) }
        )
        // The track's pill shape, applied HERE because corner radius only clips
        // a composited background when the parent applies it (same trap and
        // pattern as `tileCorners`). Half the height, minus one so it can never
        // exceed it — the AppKit backend hides a view whose radius beats its
        // size.
        .cornerRadius(max(0, pillHeight(chrome) / 2 - 1))
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
