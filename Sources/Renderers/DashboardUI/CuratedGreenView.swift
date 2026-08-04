import DashboardKit
import Foundation
import SwiftCrossUI

/// A curated single-row board on the gradient-clock theme, with the columns and
/// their relative widths given by `columns`.
///
/// - Widths are **proportional**, CSS-`fr`-style: each column takes
///   `weight / totalWeight` of the row (minus the gaps between tiles), sized from a
///   `GeometryReader` rather than from content.
/// - The clock column shows a **big, minute-precision** time built locally, so it
///   never shows seconds regardless of the clock widget's `showSeconds` option.
/// - Music uses `.mediaCompact` (smaller title text) so long song titles fit.
/// - The temps use `.standard`, unchanged.
struct CuratedGreenView: View {
    /// One column: which widget, how to lay its content out, and how wide it is
    /// relative to its siblings.
    struct Column: Equatable {
        let id: String
        let layout: WidgetLayout
        /// Relative width, like a CSS `fr` unit.
        let weight: Double

        init(_ id: String, _ layout: WidgetLayout, _ weight: Double) {
            self.id = id
            self.layout = layout
            self.weight = weight
        }
    }

    let palette: ThemePalette
    let snapshots: [AttachedWidgetSnapshot]
    let columns: [Column]

    /// Minute-precision, no seconds. Rebuilt each render (snapshots tick ~1s).
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "h:mm"
        return formatter
    }()

    var body: some View {
        GeometryReader { proxy in
            let visible = columns.filter { $0.id == "clock" || snapshot($0.id) != nil }
            let total = max(1, visible.reduce(0) { $0 + $1.weight })
            let gap = palette.widgetGap
            let available = max(1, proxy.size.width - Double(gap * max(0, visible.count - 1)))

            HStack(spacing: gap) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { item in
                    column(item.element)
                        .frame(width: max(1, available * item.element.weight / total))
                        // Corners are rounded here, by the parent: a child view's own
                        // `.cornerRadius` doesn't clip its composited background on
                        // the GTK backend.
                        .tileCorners(palette)
                }
            }
        }
    }

    /// The clock column is hand-built (for minute precision); everything else goes
    /// through the shared `TileView`.
    @ViewBuilder
    private func column(_ column: Column) -> some View {
        if column.id == "clock" {
            clockTile
        } else if let snapshot = snapshot(column.id) {
            TileView(snapshot: snapshot, palette: palette, layoutOverride: column.layout)
        }
    }

    private func snapshot(_ id: String) -> AttachedWidgetSnapshot? {
        snapshots.first { $0.id.rawValue == id }
    }

    /// The clock tile — a `.bigNumber`-style stack (title / hero / date) built
    /// by hand so the time is minute-precision. Roles mirror `TileView.style`
    /// so it matches the other tiles visually.
    private var clockTile: some View {
        VStack(alignment: .leading, spacing: Int((2 * palette.verticalScale).rounded())) {
            Text("CLOCK")
                .font(.system(size: palette.captionSize, weight: palette.bodyWeight))
                .foregroundColor(palette.secondary)
            Text(Self.timeFormatter.string(from: Date()))
                .font(.system(size: palette.headingSize * 1.6, weight: palette.headingWeight))
                .foregroundColor(palette.primary)
            if let date = snapshot("clock")?.content?.secondaryText {
                Text(date)
                    .font(.system(size: palette.bodySize, weight: palette.bodyWeight))
                    .foregroundColor(palette.text)
            }
        }
        .padding(.horizontal, palette.tilePadding)
        .padding(.vertical, palette.verticalTilePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.surface)
        .cornerRadius(Int(palette.cornerRadius.rounded()))
    }
}

/// Column specs for the curated boards.
///
/// Deliberately *not* statics on `CuratedGreenView`: statics on a `View` inherit
/// its main-actor isolation, so `DashboardModel.init` couldn't reference them.
enum BoardColumns {
    /// Clock, music, indoor, outdoor — all the same width.
    static let equalWidths: [CuratedGreenView.Column] = [
        CuratedGreenView.Column("clock", .bigNumber, 1),
        CuratedGreenView.Column("music", .mediaCompact, 1),
        CuratedGreenView.Column("indoor", .standard, 1),
        CuratedGreenView.Column("outdoor", .standard, 1),
    ]

    /// Temps narrow on the left, then a wide clock and a roomy music column
    /// (1fr / 1fr / 3fr / 2fr).
    static let wideClock: [CuratedGreenView.Column] = [
        CuratedGreenView.Column("indoor", .standard, 1),
        CuratedGreenView.Column("outdoor", .standard, 1),
        CuratedGreenView.Column("clock", .bigNumber, 3),
        CuratedGreenView.Column("music", .mediaCompact, 2),
    ]
}
