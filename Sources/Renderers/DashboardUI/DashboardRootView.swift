import DashboardKit
import SwiftCrossUI

/// Root view: lays the widget tiles out from their `GridLayout` slots, the same
/// slots the dev web renderer feeds into CSS Grid. Tiles are grouped into rows
/// by `gridSlot.row` and ordered left-to-right by `gridSlot.column`.
///
/// The model is read once into `@State`; its `@Published` snapshots drive
/// re-renders as the observer ticks.
struct DashboardRootView: View {
    @State private var model = DashboardLaunch.model
        ?? DashboardModel(theme: DarkDeskTheme())

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(background)
    }

    /// The screen below the header: the interactive MTG mode, or the widget-tile
    /// grid for every other preview.
    @ViewBuilder private var content: some View {
        if model.isMTG {
            MTGModeView(palette: model.palette, time: model.clockTime)
                .padding(model.palette.sectionMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.isBoard {
            CuratedGreenView(palette: model.palette, snapshots: model.snapshots)
                .padding(model.palette.sectionMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: model.palette.widgetGap) {
                ForEach(tiles, id: \.id.rawValue) { snapshot in
                    TileView(
                        snapshot: snapshot,
                        palette: model.palette,
                        layoutOverride: model.layoutOverride
                    )
                }
            }
            .padding(model.palette.sectionMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// A top-to-bottom gradient when the palette defines one (the gradient-clock
    /// theme), otherwise the flat background color.
    @ViewBuilder private var background: some View {
        if let stops = model.palette.backgroundGradient {
            LinearGradient(
                colors: stops,
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            model.palette.background
        }
    }

    private var header: some View {
        HStack {
            Text("DeskDashboard · \(model.previewName)")
                .font(.system(size: model.palette.captionSize, weight: model.palette.bodyWeight))
                .foregroundColor(model.palette.secondary)
            Spacer(minLength: 0)
            if model.showsPreviewControls {
                previewBar
            }
        }
        .padding(model.palette.sectionMargin)
    }

    /// A pill-shaped segmented switcher styled after the reference HTML toggle:
    /// a rounded translucent track with the active segment filled by the accent.
    /// Tap any segment to jump to that theme × layout combination.
    ///
    /// Radii are ~half the element height for a pill look. They must NOT be huge
    /// (e.g. CSS-style `999`): the AppKit backend sets `layer.cornerRadius`
    /// literally with `clipsToBounds`, and a radius larger than half the size
    /// collapses the clip mask, hiding the whole control (taps still land).
    private var segmentHeight: Int { Int(model.palette.captionSize.rounded()) + 12 }

    private var previewBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(model.previews.enumerated()), id: \.offset) { item in
                segment(item.offset)
            }
        }
        .padding(4)
        .background(model.palette.surface)
        .cornerRadius(segmentHeight / 2 + 4)
    }

    private func segment(_ index: Int) -> some View {
        let selected = index == model.previewIndex
        return Text(model.previews[index].short)
            .font(.system(size: model.palette.captionSize, weight: .semibold))
            .foregroundColor(selected ? model.palette.background : model.palette.accent)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(selected ? model.palette.accent : model.palette.accent.opacity(0))
            .cornerRadius(segmentHeight / 2)
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
