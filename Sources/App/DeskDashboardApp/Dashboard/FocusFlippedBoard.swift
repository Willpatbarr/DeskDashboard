// FocusFlippedBoard.swift — Board spec: `focus` reordered, for A/B-ing the two.

import DashboardKit
import DashboardUI

extension BoardColumns {
    /// `focus` with the columns reordered — temps first, then music, then the
    /// clock — for A/B-ing the two arrangements from the switcher.
    public static let focusFlipped: [BoardColumn] = [
        BoardColumn(
            rows: [
                BoardRow("indoor", .fittedValue),
                BoardRow("outdoor", .fittedValue),
            ],
            1,
            containerless: true
        ),
        BoardColumn("music", .nowPlaying, 2, containerless: true),
        BoardColumn("clock", .centeredValue, 3, containerless: true, hidesTitle: true),
    ]
}
