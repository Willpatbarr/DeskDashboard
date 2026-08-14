// BoardColumn.swift — Board vocabulary: the column/row types board specs are written in.

import DashboardKit

// The vocabulary boards are written in, and the namespace their specs hang off.
//
// **This file is the scaffold.** Each board lives in its own file in this folder,
// declared as a static on `BoardColumns`:
//
//     extension BoardColumns {
//         static let myBoard: [BoardColumn] = [ … ]
//     }
//
// So adding an arrangement is one new file plus a `Preview` entry in
// `DashboardModel` to make it selectable — nothing to edit here.
//
// NOTE: this is *not* the same thing as DashboardKit's `Layout`/`GridLayout`.
// That assigns each widget a `gridSlot` from its `WidgetSize` and drives the dev
// web renderer's CSS Grid; these specs are what actually produce the columns and
// rows on the panel, and they ignore grid slots entirely.

/// One column of a board: one or more widgets stacked vertically, how wide the
/// column is relative to its siblings, and whether its tiles keep their chrome.
public struct BoardColumn: Equatable, Sendable {
    public let rows: [BoardRow]
    /// Relative width, like a CSS `fr` unit.
    public let weight: Double
    /// Renders the tiles without their chrome — just the content, directly on
    /// the board's gradient.
    public let containerless: Bool
    /// Sizes the column to its CONTENT instead of to `weight`, leaving the rest of
    /// the band to its flexible siblings.
    ///
    /// `weight` is ignored for a hugging column. There must be at least one
    /// non-hugging column in the band to absorb the leftover width — a band of
    /// nothing but hugging columns leaves a gap at the trailing edge.
    public let hugsContent: Bool

    /// The common case: a column holding a single widget.
    public init(
        _ id: String,
        _ layout: WidgetLayout,
        _ weight: Double,
        containerless: Bool = false,
        hidesTitle: Bool = false,
        hugsContent: Bool = false,
        widthSample: String? = nil,
        centersVertically: Bool = false
    ) {
        self.init(
            rows: [
                BoardRow(
                    id,
                    layout,
                    hidesTitle: hidesTitle,
                    widthSample: widthSample,
                    centersVertically: centersVertically
                )
            ],
            weight,
            containerless: containerless,
            hugsContent: hugsContent
        )
    }

    /// A column stacking several widgets vertically (equal heights).
    public init(
        rows: [BoardRow],
        _ weight: Double,
        containerless: Bool = false,
        hugsContent: Bool = false
    ) {
        self.rows = rows
        self.weight = weight
        self.containerless = containerless
        self.hugsContent = hugsContent
    }
}

/// One full-width horizontal band of a board: a row of columns, and how tall the
/// band is relative to its siblings.
///
/// Bands are what let a board be something other than a single row of columns —
/// a full-width clock over a row of three small tiles, say, which columns alone
/// cannot express (a column's rows are confined to that column's width).
///
/// Every board is drawn as bands: a plain `[BoardColumn]` board is simply one
/// band of weight 1. That uniformity is deliberate — the renderer has no
/// banded-vs-plain branch, because branching the view structure on this backend
/// has blanked whole boards before.
public struct BoardBand: Equatable, Sendable {
    public let columns: [BoardColumn]
    /// Relative height, like a CSS `fr` unit.
    public let weight: Double

    public init(_ columns: [BoardColumn], _ weight: Double = 1) {
        self.columns = columns
        self.weight = max(0.0001, weight)
    }
}

/// One widget within a column: which one, how to lay its content out, and
/// whether to drop its title label.
public struct BoardRow: Equatable, Sendable {
    public let id: String
    public let layout: WidgetLayout
    /// Relative height within the column, like a CSS `fr` unit. Rows default to
    /// equal shares; give one a larger weight when it needs the room (the MTG
    /// centre column runs 1:2, clock over turn, because a display-size number
    /// doesn't fit half a column).
    public let weight: Double
    public let hidesTitle: Bool
    /// Worst-case value used to size a content-hugging column, instead of whatever
    /// the widget happens to be showing right now.
    ///
    /// Give a temperature `"999°F"`: the tile is then as wide as it will ever need
    /// to be, so it does NOT resize when the reading crosses from two digits to
    /// three — and neither does the flexible tile beside it, which would otherwise
    /// twitch every time the value changed. Ignored unless the column hugs.
    public let widthSample: String?
    /// Centres the tile's content in its height instead of pinning it to the top.
    /// For a row much shorter than a normal tile — see `TileView.centersVertically`.
    public let centersVertically: Bool

    public init(
        _ id: String,
        _ layout: WidgetLayout,
        _ weight: Double = 1,
        hidesTitle: Bool = false,
        widthSample: String? = nil,
        centersVertically: Bool = false
    ) {
        self.id = id
        self.layout = layout
        self.weight = max(0.0001, weight)
        self.hidesTitle = hidesTitle
        self.widthSample = widthSample
        self.centersVertically = centersVertically
    }
}

/// Namespace for the curated board specs, one per file in this folder.
///
/// Deliberately *not* statics on `BoardScreen`: statics on a `View` inherit
/// its main-actor isolation, so `DashboardModel.init` couldn't reference them.
public enum BoardColumns {}
