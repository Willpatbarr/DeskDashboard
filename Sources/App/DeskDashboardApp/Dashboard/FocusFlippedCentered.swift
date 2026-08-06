// FocusFlippedCentered.swift — Board spec: `focusFlipped` with the music text centred.

import DashboardKit
import DashboardUI

extension BoardColumns {
    /// `focusFlipped` with one change: the music tile centres its label, artist
    /// and song (`.nowPlayingCentered`) instead of leading-aligning them.
    public static let focusFlippedCentered: [BoardColumn] = [
        BoardColumn(
            rows: [
                BoardRow("indoor", .fittedValue),
                BoardRow("outdoor", .fittedValue),
            ],
            1,
            containerless: true
        ),
        BoardColumn("music", .nowPlayingCentered, 2, containerless: true),
        BoardColumn("clock", .centeredValue(subtitle: .above), 3, containerless: true, hidesTitle: true),
    ]
}
