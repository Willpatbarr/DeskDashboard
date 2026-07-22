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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(model.palette.background)
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

    /// A segmented bar: one numbered segment per preview, the active one filled
    /// with the accent. Tap any segment to jump straight to it — the reusable
    /// hook for layout switching.
    private var previewBar: some View {
        HStack(spacing: 4) {
            ForEach(Array(model.previews.enumerated()), id: \.offset) { item in
                segment(item.offset)
            }
        }
    }

    private func segment(_ index: Int) -> some View {
        let selected = index == model.previewIndex
        return Text("\(index + 1)")
            .font(.system(size: model.palette.captionSize, weight: .bold))
            .foregroundColor(selected ? model.palette.background : model.palette.secondary)
            .padding(6)
            .frame(width: 34)
            .background(selected ? model.palette.accent : model.palette.surface)
            .cornerRadius(6)
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
