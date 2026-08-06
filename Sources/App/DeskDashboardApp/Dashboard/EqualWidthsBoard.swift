// EqualWidthsBoard.swift — Board spec: clock, music, indoor, outdoor at equal widths.

import DashboardKit
import DashboardUI

extension BoardColumns {
    /// Clock, music, indoor, outdoor — all the same width, and the clock keeps the
    /// original top-left `.bigNumber` treatment (the centred one is the wide board's).
    public static let equalWidths: [BoardColumn] = [
        BoardColumn("clock", .bigNumber, 1),
        BoardColumn("music", .mediaStacked, 1),
        BoardColumn("indoor", .standard, 1),
        BoardColumn("outdoor", .standard, 1),
    ]
}
