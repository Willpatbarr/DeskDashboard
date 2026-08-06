// WideClockBoard.swift — Board spec: narrow temps, a wide centred clock, roomy music (1fr/1fr/3fr/2fr).

import DashboardKit
import DashboardUI

extension BoardColumns {
    /// Temps narrow on the left, then a wide clock and a roomy music column
    /// (1fr / 1fr / 3fr / 2fr).
    public static let wideClock: [BoardColumn] = [
        BoardColumn("indoor", .standard, 1),
        BoardColumn("outdoor", .standard, 1),
        BoardColumn("clock", .centeredValue, 3),
        BoardColumn("music", .mediaStacked, 2),
    ]
}
