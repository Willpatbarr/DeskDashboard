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
            ScrollView {
                VStack(spacing: model.palette.widgetGap) {
                    ForEach(rows, id: \.id) { row in
                        HStack(spacing: model.palette.widgetGap) {
                            ForEach(row.tiles, id: \.id.rawValue) { snapshot in
                                TileView(snapshot: snapshot, palette: model.palette)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(model.palette.sectionMargin)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(model.palette.background)
    }

    private var header: some View {
        HStack {
            Text("DeskDashboard · \(model.themeName)")
                .font(.system(size: model.palette.captionSize, weight: model.palette.bodyWeight))
                .foregroundColor(model.palette.secondary)
            Spacer(minLength: 0)
        }
        .padding(model.palette.sectionMargin)
    }

    // MARK: - Grid mapping

    private struct GridRow {
        let id: Int
        let tiles: [AttachedWidgetSnapshot]
    }

    /// Visible snapshots grouped into rows by grid slot, each row ordered by
    /// column. Widgets with no grid slot fall into row 0, column 0.
    private var rows: [GridRow] {
        let visible = model.snapshots.filter {
            $0.placement.visibility == .visible
        }
        let grouped = Dictionary(grouping: visible) {
            $0.placement.gridSlot?.row ?? 0
        }
        return grouped.keys.sorted().map { row in
            GridRow(
                id: row,
                tiles: grouped[row, default: []].sorted {
                    ($0.placement.gridSlot?.column ?? 0)
                        < ($1.placement.gridSlot?.column ?? 0)
                }
            )
        }
    }
}
