// RuledBoard.swift — Board spec: the equal-widths board, ruled.

import DashboardKit
import DashboardUI

extension BoardColumns {
    /// `equalWidths` with the ruled layouts: same four widgets at the same
    /// widths, drawn with a hairline under each label and a footer pinned under a
    /// second hairline.
    ///
    /// The clock takes `.ruled` rather than `.bigNumber` so its label, value and
    /// rules sit on the same lines as the temperature tiles — the whole point of
    /// the treatment is that the row reads as one ruled sheet.
    public static let ruled: [BoardColumn] = [
        BoardColumn("clock", .ruled, 1),
        BoardColumn("music", .ruledMedia, 1),
        BoardColumn("indoor", .ruled, 1),
        BoardColumn("outdoor", .ruled, 1),
    ]
}
