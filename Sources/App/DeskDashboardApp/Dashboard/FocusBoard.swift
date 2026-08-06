// FocusBoard.swift — Board spec: chrome-less music, clock and a stacked temp column (2fr/3fr/1fr).

import DashboardKit
import DashboardUI

extension BoardColumns {
    /// Everything chrome-less on the gradient: music with the transport row
    /// (2fr), the centred clock with its label hidden (3fr), and a 1fr column
    /// of indoor over outdoor temps, each just a centred label + a value sized
    /// to fill its half.
    public static let focus: [BoardColumn] = [
        BoardColumn("music", .nowPlaying, 2, containerless: true),
        BoardColumn("clock", .centeredValue, 3, containerless: true, hidesTitle: true),
        BoardColumn(
            rows: [
                BoardRow("indoor", .fittedValue),
                BoardRow("outdoor", .fittedValue),
            ],
            1,
            containerless: true
        ),
    ]
}
