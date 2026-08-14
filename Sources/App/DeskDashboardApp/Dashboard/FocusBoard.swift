// FocusBoard.swift — Board spec: a full-width clock over a row of three small tiles (4fr/1fr).

import DashboardKit
import DashboardUI

extension BoardColumns {
    /// Two bands: the clock alone across the whole board, then music and the two
    /// temps sharing a short strip underneath.
    ///
    ///     ┌──────────────────────────────┐
    ///     │            CLOCK             │  4fr
    ///     ├──────────────┬───────┬───────┤
    ///     │    MUSIC     │INDOOR │OUTDOOR│  1fr
    ///     └──────────────┴───────┴───────┘
    ///
    /// The clock keeps `.centeredValue` with its label hidden, so it centres in
    /// its band and gets the full width to fill.
    ///
    /// The bottom three take `.miniStat` — label over a value at the *supporting*
    /// size, two lines and no more — rather than the `.fittedValue` /
    /// `.nowPlaying` treatments this board used when every widget had a
    /// full-height column. That is the consequence of the shape: a 1fr band is
    /// ~70px on the Pi's strip, so a value sized to fill its tile is taller than
    /// the whole band, and even a three-line layout overflows it.
    public static let focus: [BoardBand] = [
        BoardBand([
            BoardColumn("clock", .centeredValue, 1, containerless: true, hidesTitle: true)
        ], 4),
        BoardBand([
            // Music is the only flexible column, so it absorbs everything the two
            // temps don't need — and with that much room it can afford the artist
            // next to the song (`detail: true`).
            BoardColumn("music", .miniStat(detail: true), 1, centersVertically: true),
            // Sized for "999°F" — no temperature anywhere on earth needs a fourth
            // digit, and sizing to the worst case once keeps these tiles (and the
            // music tile beside them) from resizing as the readings change.
            BoardColumn(
                "indoor", .miniStat, 1,
                hugsContent: true, widthSample: "999°F", centersVertically: true
            ),
            BoardColumn(
                "outdoor", .miniStat, 1,
                hugsContent: true, widthSample: "999°F", centersVertically: true
            ),
        ], 1),
    ]
}
