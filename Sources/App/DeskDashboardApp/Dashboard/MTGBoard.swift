// MTGBoard.swift — Board spec: four life seats flanking a clock-over-turn centre.

import DashboardKit
import DashboardUI

extension BoardColumns {
    /// The Magic life/turn tracker, as a board of ordinary widgets.
    ///
    /// This replaced a hand-built `MTGScreen` view. Everything it needed already
    /// existed once widgets could take input: five equal columns, the centre one
    /// stacking the clock over the turn counter — the same `rows:` support the
    /// focus boards use for their temperature column.
    ///
    /// The clock reuses the real clock widget at `.minimal`; the old screen drew
    /// its own accent-coloured mini clock, so this one is white. Every tile keeps
    /// its chrome, as the original panels did.
    public static let mtg: [BoardColumn] = [
        BoardColumn("life1", .lifeCounter, 1),
        BoardColumn("life2", .lifeCounter, 1),
        BoardColumn(
            rows: [
                // 1:2 — the clock only needs a line; the turn counter draws a
                // display-size number plus a label and a reset badge.
                // `fittedValue` with the label hidden: the clock scales to its
                // share rather than carrying a fixed hero size that wouldn't fit.
                BoardRow("clock", .fittedValue, 1, hidesTitle: true),
                BoardRow("turn", .turnCounter, 2),
            ],
            1
        ),
        BoardColumn("life3", .lifeCounter, 1),
        BoardColumn("life4", .lifeCounter, 1),
    ]
}
