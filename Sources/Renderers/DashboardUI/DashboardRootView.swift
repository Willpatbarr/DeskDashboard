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
            let palette = model.palette(
                for: Viewport(width: proxy.size.width, height: proxy.size.height)
            )

            VStack(spacing: 0) {
                header(palette)
                content(palette)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(background(palette))
        }
    }

    /// The screen below the header: the interactive MTG mode, or the widget-tile
    /// grid for every other preview.
    @ViewBuilder private func content(_ palette: ThemePalette) -> some View {
        if model.isMTG {
            MTGModeView(palette: palette, time: model.clockTime)
                .padding(palette.sectionMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.isBoard {
            CuratedGreenView(palette: palette, snapshots: model.snapshots)
                .padding(palette.sectionMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: palette.widgetGap) {
                ForEach(tiles, id: \.id.rawValue) { snapshot in
                    TileView(
                        snapshot: snapshot,
                        palette: palette,
                        layoutOverride: model.layoutOverride
                    )
                }
            }
            .padding(palette.sectionMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func header(_ palette: ThemePalette) -> some View {
        HStack {
            Text("DeskDashboard · \(model.previewName)")
                .font(.system(size: palette.captionSize, weight: palette.bodyWeight))
                .foregroundColor(palette.secondary)
            Spacer(minLength: 0)
            if model.showsPreviewControls {
                previewBar(palette)
            }
        }
        .padding(palette.sectionMargin)
    }

    /// A pill-shaped segmented switcher styled after the reference HTML toggle:
    /// a rounded translucent track with the active segment filled by the accent.
    /// Tap any segment to jump to that theme × layout combination.
    ///
    /// Radii are ~half the element height for a pill look. They must NOT be huge
    /// (e.g. CSS-style `999`): the AppKit backend sets `layer.cornerRadius`
    /// literally with `clipsToBounds`, and a radius larger than half the size
    /// collapses the clip mask, hiding the whole control (taps still land).
    /// Segment padding, scaled with the rest of the board so the pill keeps its
    /// shape on any screen.
    private func segmentInsets(_ palette: ThemePalette) -> (vertical: Int, horizontal: Int, track: Int) {
        (
            vertical: Int((6 * palette.scale).rounded()),
            horizontal: Int((14 * palette.scale).rounded()),
            track: Int((4 * palette.scale).rounded())
        )
    }

    private func segmentHeight(_ palette: ThemePalette) -> Int {
        Int(palette.captionSize.rounded()) + segmentInsets(palette).vertical * 2
    }

    private func previewBar(_ palette: ThemePalette) -> some View {
        let insets = segmentInsets(palette)
        return HStack(spacing: 0) {
            ForEach(Array(model.previews.enumerated()), id: \.offset) { item in
                segment(item.offset, palette)
            }
        }
        .padding(insets.track)
        .background(palette.surface)
        .cornerRadius(segmentHeight(palette) / 2 + insets.track)
    }

    private func segment(_ index: Int, _ palette: ThemePalette) -> some View {
        let selected = index == model.previewIndex
        let insets = segmentInsets(palette)
        return Text(model.previews[index].short)
            .font(.system(size: palette.captionSize, weight: .semibold))
            .foregroundColor(selected ? palette.background : palette.accent)
            .padding(.vertical, insets.vertical)
            .padding(.horizontal, insets.horizontal)
            .background(selected ? palette.accent : palette.accent.opacity(0))
            .cornerRadius(segmentHeight(palette) / 2)
            .onTapGesture {
                model.select(index)
            }
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
