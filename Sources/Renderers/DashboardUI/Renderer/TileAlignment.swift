// TileAlignment.swift — Which edge a tile's contents line up on, chosen in edit mode.

import SwiftCrossUI

/// Horizontal alignment of a widget's contents, picked per widget from the edit
/// overlay's pill.
///
/// This is a *renderer* concern, not a framework one: a `WidgetLayout` describes
/// what a widget shows and in what structure, and every layout's structure is
/// already a stack of runs. So alignment doesn't need a new case per layout —
/// `TileView`'s interpreter threads one value into the two places that decide
/// where a run sits (`.stack(.vertical)` and `.centered`) plus the tile's own
/// frame, and every existing layout picks it up for free. Adding a layout later
/// costs nothing here.
enum TileAlignment: String, CaseIterable {
    case leading
    case center
    case trailing

    /// Pill labels. Physical directions rather than `leading`/`trailing` because
    /// the pill is a direct-manipulation control — you're pointing at a side of
    /// the screen, not naming a writing direction.
    var label: String {
        switch self {
        case .leading: "Left"
        case .center: "Center"
        case .trailing: "Right"
        }
    }

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }

    /// The tile's own content frame pins its contents to the TOP by default; only
    /// the horizontal component is chosen from the edit overlay.
    var topAligned: Alignment {
        Alignment(horizontal: horizontal, vertical: .top)
    }

    /// `topAligned`, or vertically centred instead. Centring is opt-in per tile
    /// (`BoardRow.centersVertically`) rather than the default: most layouts fill
    /// their tile's height — a footer pinned under a spacer, say — so centring
    /// them changes nothing, but the ones that DON'T fill it would all shift.
    func aligned(centeredVertically: Bool) -> Alignment {
        Alignment(horizontal: horizontal, vertical: centeredVertically ? .center : .top)
    }
}
