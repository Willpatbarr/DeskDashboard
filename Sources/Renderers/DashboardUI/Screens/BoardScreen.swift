// BoardScreen.swift — Screen: renders a board spec as bands of proportional columns of tiles.

import DashboardKit
import Foundation
import SwiftCrossUI

/// A curated board, given as `bands` — full-width horizontal bands, each a row of
/// columns. Most boards are a single band; `BoardBand` explains why every board
/// goes through the banded path even so.
///
/// - Widths AND heights are **proportional**, CSS-`fr`-style: each band takes
///   `weight / totalWeight` of the height and each column the same share of its
///   band's width (minus the gaps between tiles), all sized from a
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
    let bands: [BoardBand]
    /// Overrides each column's authored `containerless` flag; `.authored` keeps it.
    var containerMode: ContainerMode = .authored
    /// Veils every tile while the header's Edit toggle is on.
    var isEditing: Bool = false
    /// Per-widget content alignment, keyed by widget id; missing ids draw leading.
    var alignments: [String: TileAlignment] = [:]
    /// Raised as `(widget id, pill index)` when a tile's alignment pill is tapped.
    var onSelectAlignment: ((String, Int) -> Void)? = nil
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
            // Bands get EXACT carved heights, never greedy frames — the same rule
            // the root view's header/content split and a column's rows follow. A
            // greedy band steals from its siblings and runs off the panel.
            let height = proxy.size.height.isFinite ? max(0, proxy.size.height) : 0
            let gaps = Double(palette.verticalWidgetGap * max(0, bands.count - 1))
            let usable = height > gaps ? height - gaps : 0
            let total = max(0.0001, bands.reduce(0) { $0 + $1.weight })

            VStack(spacing: palette.verticalWidgetGap) {
                ForEach(Array(bands.enumerated()), id: \.offset) { item in
                    // The band's height is computed HERE and passed down as well as
                    // applied, because the columns inside it carve their rows from
                    // it — and a nested `GeometryReader` can't be used to
                    // re-measure (it reports infinity on probe passes, and
                    // `Int(inf)` traps).
                    let bandHeight = max(1, usable * item.element.weight / total)
                    band(item.element, width: proxy.size.width, height: bandHeight)
                        .frame(height: bandHeight)
                }
            }
        }
    }

    /// One band: its columns side by side, each taking its share of the width.
    ///
    private func band(_ band: BoardBand, width: Double, height: Double) -> some View {
        let visible = band.columns.filter { column in
            column.rows.contains { $0.id == "clock" || snapshot($0.id) != nil }
        }
        let total = max(1, visible.reduce(0) { $0 + $1.weight })
        let gap = palette.widgetGap
        let measured = width.isFinite ? max(0, width) : 0
        let available = max(1, measured - Double(gap * max(0, visible.count - 1)))

        // Hugging columns get an EXPLICIT width, estimated from their content —
        // see `estimatedWidth(of:)` for why frames can't do this — and the
        // flexible columns divide whatever is left by weight.
        let hugWidths: [Int: Double] = Dictionary(
            uniqueKeysWithValues: visible.enumerated().compactMap { index, column in
                guard column.hugsContent else { return nil }
                return (index, huggedWidth(column))
            }
        )
        let hugged = hugWidths.values.reduce(0, +)
        let flexibleTotal = max(
            0.0001,
            visible.filter { !$0.hugsContent }.reduce(0) { $0 + $1.weight }
        )
        let forFlexible = max(1, available - hugged)

        return HStack(spacing: gap) {
            ForEach(Array(visible.enumerated()), id: \.offset) { item in
                column(item.element, height: height)
                    .frame(
                        width: hugWidths[item.offset]
                            ?? max(1, forFlexible * item.element.weight / flexibleTotal)
                    )
            }
        }
    }

    /// Width for a content-hugging column: the widest estimate among its rows, plus
    /// the tile's horizontal padding, plus a couple of points of slack so an
    /// under-estimate truncates nothing.
    ///
    /// A row's `widthSample` stands in for its live value, so the column is sized
    /// for the WORST case once (`"999°F"`) rather than re-sized every time the
    /// reading changes width — which would shove its flexible neighbour around on
    /// every tick.
    private func huggedWidth(_ column: BoardColumn) -> Double {
        let content = column.rows.compactMap { row -> Double? in
            guard let snapshot = resolvedSnapshot(row) else { return nil }
            let resolved = TileView(
                snapshot: snapshot,
                palette: palette,
                layoutOverride: row.layout,
                hidesTitle: row.hidesTitle
            ).layoutContent
            let sized = row.widthSample.map { sample in
                WidgetContent(
                    title: resolved.title,
                    primaryText: sample,
                    secondaryText: resolved.secondaryText,
                    accessoryText: resolved.accessoryText,
                    progress: resolved.progress,
                    elapsedText: resolved.elapsedText,
                    durationText: resolved.durationText,
                    isPlaying: resolved.isPlaying,
                    metadata: resolved.metadata
                )
            } ?? resolved
            return palette.estimatedWidth(of: row.layout.makeView(sized))
        }
        let widest = content.max() ?? 0
        return (widest + Double(palette.tilePadding * 2) + 4).rounded()
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
                row(item.element, containerless: containerless, hugsWidth: column.hugsContent)
                    .frame(height: max(1, usable * item.element.weight / totalWeight))
            }
        }
    }

    @ViewBuilder
    private func row(_ row: BoardRow, containerless: Bool, hugsWidth: Bool = false) -> some View {
        if let snapshot = resolvedSnapshot(row) {
            TileView(
                snapshot: snapshot,
                palette: palette,
                layoutOverride: row.layout,
                containerless: containerless,
                hidesTitle: row.hidesTitle,
                alignment: alignments[row.id],
                centersVertically: row.centersVertically,
                hugsWidth: hugsWidth,
                onAction: { action, isHold, isHoldable in
                    onAction?(row.id, action, isHold, isHoldable)
                },
                onPressEnded: { onPressEnded?() }
            )
            .editScrim(
                palette,
                active: isEditing,
                // The PILL needs a concrete selection, so an untouched tile
                // shows Left even where its layout centres itself. Cosmetic only
                // — the content still draws as the layout intends until a pick is
                // actually made.
                alignment: alignments[row.id] ?? .leading,
                onSelectAlignment: { onSelectAlignment?(row.id, $0) }
            )
            .tileCorners(palette, rounded: !containerless)
            .tileBorder(palette, rounded: !containerless)
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
