import DashboardKit
import Foundation
import SwiftCrossUI

/// A curated single-row board on the gradient-clock theme, with the columns and
/// their relative widths given by `columns`.
///
/// - Widths are **proportional**, CSS-`fr`-style: each column takes
///   `weight / totalWeight` of the row (minus the gaps between tiles), sized from a
///   `GeometryReader` rather than from content.
/// - The clock column shows a **big, minute-precision** time, centred in its tile
///   via `WidgetLayout.centeredValue`; its text is rewritten locally so it never
///   shows seconds regardless of the clock widget's `showSeconds` option.
/// - Music uses `.mediaStacked` — artist above a full-size song title that
///   wraps, so long titles still fit.
/// - The temps use `.standard`, unchanged.
struct CuratedGreenView: View {
    /// One column: one or more widgets stacked vertically, how wide the column
    /// is relative to its siblings, and whether its tiles keep their chrome.
    struct Column: Equatable {
        /// One widget within the column: which one, how to lay its content out,
        /// and whether to drop its title label.
        struct Row: Equatable {
            let id: String
            let layout: WidgetLayout
            let hidesTitle: Bool

            init(_ id: String, _ layout: WidgetLayout, hidesTitle: Bool = false) {
                self.id = id
                self.layout = layout
                self.hidesTitle = hidesTitle
            }
        }

        let rows: [Row]
        /// Relative width, like a CSS `fr` unit.
        let weight: Double
        /// Renders the tiles without their chrome — just the content, directly
        /// on the board's gradient.
        let containerless: Bool

        /// The common case: a column holding a single widget.
        init(
            _ id: String,
            _ layout: WidgetLayout,
            _ weight: Double,
            containerless: Bool = false,
            hidesTitle: Bool = false
        ) {
            self.init(
                rows: [Row(id, layout, hidesTitle: hidesTitle)],
                weight,
                containerless: containerless
            )
        }

        /// A column stacking several widgets vertically (equal heights).
        init(
            rows: [Row],
            _ weight: Double,
            containerless: Bool = false
        ) {
            self.rows = rows
            self.weight = weight
            self.containerless = containerless
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
            let visible = columns.filter { column in
                column.rows.contains { $0.id == "clock" || snapshot($0.id) != nil }
            }
            let total = max(1, visible.reduce(0) { $0 + $1.weight })
            let gap = palette.widgetGap
            let available = max(1, proxy.size.width - Double(gap * max(0, visible.count - 1)))

            HStack(spacing: gap) {
                ForEach(Array(visible.enumerated()), id: \.offset) { item in
                    column(item.element, height: proxy.size.height)
                        .frame(width: max(1, available * item.element.weight / total))
                }
            }
        }
    }

    /// Every row goes through the shared `TileView`; the clock's *content* is
    /// swapped for a minute-precision time rather than the tile being rebuilt by
    /// hand. That keeps one code path for tile chrome, and the centred treatment
    /// lives in `WidgetLayout.centeredValue` so no other layout is affected.
    ///
    /// The structure is UNIFORM — always a VStack of rows, even for one row —
    /// because branching the view structure blanked every board (see the trap
    /// notes). Corners are still applied here, by the tile's parent (radius 0
    /// when containerless — same chain either way).
    ///
    /// Rows get EXACT equal heights carved from the column's `height`, not
    /// greedy frames: greedy siblings don't split fairly here (the outdoor temp
    /// ran off the bottom of the panel), same trap as the root view's bands.
    private func column(_ column: Column, height: Double) -> some View {
        let count = max(1, column.rows.count)
        let gaps = Double(palette.verticalWidgetGap * (count - 1))
        let rowHeight = height.isFinite && height > gaps
            ? (height - gaps) / Double(count)
            : 0
        return VStack(spacing: palette.verticalWidgetGap) {
            ForEach(Array(column.rows.enumerated()), id: \.offset) { item in
                row(item.element, containerless: column.containerless)
                    .frame(height: max(1, rowHeight))
            }
        }
    }

    @ViewBuilder
    private func row(_ row: Column.Row, containerless: Bool) -> some View {
        if let snapshot = resolvedSnapshot(row) {
            TileView(
                snapshot: snapshot,
                palette: palette,
                layoutOverride: row.layout,
                containerless: containerless,
                hidesTitle: row.hidesTitle
            )
            .tileCorners(palette, rounded: !containerless)
        }
    }

    private func snapshot(_ id: String) -> AttachedWidgetSnapshot? {
        snapshots.first { $0.id.rawValue == id }
    }

    /// The row's snapshot, with the clock's time rewritten to minute precision.
    ///
    /// The composed clock widget runs with `showSeconds()`, so its `primaryText`
    /// ticks every second; the board wants a calm "9:21".
    private func resolvedSnapshot(_ row: Column.Row) -> AttachedWidgetSnapshot? {
        guard let snapshot = snapshot(row.id) else { return nil }
        guard row.id == "clock" else { return snapshot }

        return AttachedWidgetSnapshot(
            id: snapshot.id,
            configuration: snapshot.configuration,
            placement: snapshot.placement,
            content: WidgetContent(
                title: snapshot.content?.title ?? snapshot.configuration.title,
                primaryText: Self.timeFormatter.string(from: Date()),
                secondaryText: snapshot.content?.secondaryText,
                accessoryText: snapshot.content?.accessoryText,
                metadata: []
            )
        )
    }
}

/// Column specs for the curated boards.
///
/// Deliberately *not* statics on `CuratedGreenView`: statics on a `View` inherit
/// its main-actor isolation, so `DashboardModel.init` couldn't reference them.
enum BoardColumns {
    /// Clock, music, indoor, outdoor — all the same width, and the clock keeps the
    /// original top-left `.bigNumber` treatment (the centred one is the wide board's).
    static let equalWidths: [CuratedGreenView.Column] = [
        CuratedGreenView.Column("clock", .bigNumber, 1),
        CuratedGreenView.Column("music", .mediaStacked, 1),
        CuratedGreenView.Column("indoor", .standard, 1),
        CuratedGreenView.Column("outdoor", .standard, 1),
    ]

    /// Temps narrow on the left, then a wide clock and a roomy music column
    /// (1fr / 1fr / 3fr / 2fr).
    static let wideClock: [CuratedGreenView.Column] = [
        CuratedGreenView.Column("indoor", .standard, 1),
        CuratedGreenView.Column("outdoor", .standard, 1),
        CuratedGreenView.Column("clock", .centeredValue, 3),
        CuratedGreenView.Column("music", .mediaStacked, 2),
    ]

    /// Everything chrome-less on the gradient: music with the transport row
    /// (2fr), the centred clock with its label hidden (3fr), and a 1fr column
    /// of indoor over outdoor temps, each just a centred label + a value sized
    /// to fill its half.
    static let focus: [CuratedGreenView.Column] = [
        CuratedGreenView.Column("music", .nowPlaying, 2, containerless: true),
        CuratedGreenView.Column("clock", .centeredValue, 3, containerless: true, hidesTitle: true),
        CuratedGreenView.Column(
            rows: [
                CuratedGreenView.Column.Row("indoor", .fittedValue),
                CuratedGreenView.Column.Row("outdoor", .fittedValue),
            ],
            1,
            containerless: true
        ),
    ]

    /// `focus` with the columns reordered — temps first, then music, then the
    /// clock — for A/B-ing the two arrangements from the switcher.
    static let focusFlipped: [CuratedGreenView.Column] = [
        CuratedGreenView.Column(
            rows: [
                CuratedGreenView.Column.Row("indoor", .fittedValue),
                CuratedGreenView.Column.Row("outdoor", .fittedValue),
            ],
            1,
            containerless: true
        ),
        CuratedGreenView.Column("music", .nowPlaying, 2, containerless: true),
        CuratedGreenView.Column("clock", .centeredValue, 3, containerless: true, hidesTitle: true),
    ]
}
