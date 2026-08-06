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

    /// The common case: a column holding a single widget.
    public init(
        _ id: String,
        _ layout: WidgetLayout,
        _ weight: Double,
        containerless: Bool = false,
        hidesTitle: Bool = false
    ) {
        self.init(
            rows: [BoardRow(id, layout, hidesTitle: hidesTitle)],
            weight,
            containerless: containerless
        )
    }

    /// A column stacking several widgets vertically (equal heights).
    public init(
        rows: [BoardRow],
        _ weight: Double,
        containerless: Bool = false
    ) {
        self.rows = rows
        self.weight = weight
        self.containerless = containerless
    }
}

/// One widget within a column: which one, how to lay its content out, and
/// whether to drop its title label.
public struct BoardRow: Equatable, Sendable {
    public let id: String
    public let layout: WidgetLayout
    public let hidesTitle: Bool

    public init(_ id: String, _ layout: WidgetLayout, hidesTitle: Bool = false) {
        self.id = id
        self.layout = layout
        self.hidesTitle = hidesTitle
    }
}

/// Namespace for the curated board specs, one per file in this folder.
///
/// Deliberately *not* statics on `BoardScreen`: statics on a `View` inherit
/// its main-actor isolation, so `DashboardModel.init` couldn't reference them.
public enum BoardColumns {}
