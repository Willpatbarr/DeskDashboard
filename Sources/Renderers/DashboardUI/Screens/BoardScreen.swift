// BoardScreen.swift — Screen: renders a board spec as proportional columns of tiles.

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
///
/// This is the *renderer* for a board. The boards themselves — which widgets, in
/// which order, at which weights — are data, one file each in `Boards/`.
struct BoardScreen: View {
    let palette: ThemeToSCUIPalette
    let snapshots: [AttachedWidgetSnapshot]
    let columns: [BoardColumn]
    /// Overrides each column's authored `containerless` flag; `.authored` keeps it.
    var containerMode: ContainerMode = .authored
    /// Raised as `(widget id, action, cameFromHold)` when a tile reports a gesture.
    var onAction: ((String, String, Bool, Bool) -> Void)? = nil
    /// Raised when a press ends, so a repeating hold can stop.
    var onPressEnded: (() -> Void)? = nil

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
    private func column(_ column: BoardColumn, height: Double) -> some View {
        let count = max(1, column.rows.count)
        let gaps = Double(palette.verticalWidgetGap * (count - 1))
        let usable = height.isFinite && height > gaps ? height - gaps : 0
        let totalWeight = max(0.0001, column.rows.reduce(0) { $0 + $1.weight })
        return VStack(spacing: palette.verticalWidgetGap) {
            let containerless = containerMode.isContainerless(authored: column.containerless)
            ForEach(Array(column.rows.enumerated()), id: \.offset) { item in
                row(item.element, containerless: containerless)
                    .frame(height: max(1, usable * item.element.weight / totalWeight))
            }
        }
    }

    @ViewBuilder
    private func row(_ row: BoardRow, containerless: Bool) -> some View {
        if let snapshot = resolvedSnapshot(row) {
            TileView(
                snapshot: snapshot,
                palette: palette,
                layoutOverride: row.layout,
                containerless: containerless,
                hidesTitle: row.hidesTitle,
                onAction: { action, isHold, isHoldable in
                    onAction?(row.id, action, isHold, isHoldable)
                },
                onPressEnded: { onPressEnded?() }
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
    private func resolvedSnapshot(_ row: BoardRow) -> AttachedWidgetSnapshot? {
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
