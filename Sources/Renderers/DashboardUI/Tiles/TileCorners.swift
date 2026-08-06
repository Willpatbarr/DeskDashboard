// TileCorners.swift — Modifier rounding a tile's corners from the call site (GTK).

import SwiftCrossUI

// A view modifier, not a translation — split out of the palette file so that one
// stays purely about turning theme tokens into SwiftCrossUI values.

extension View {
    /// Rounds a tile/panel's corners **from the call site**.
    ///
    /// Necessary because `.cornerRadius` applied *inside* a child `View` struct's
    /// own body does not clip that view's composited background on the GTK
    /// backend. Verified on the Pi: `TileView` tiles rendered with square corners
    /// while a tile built inline in the parent — same modifier chain, same radius —
    /// rendered rounded. Moving the call to the parent fixed it.
    func tileCorners(_ palette: ThemeToSCUIPalette) -> some View {
        cornerRadius(Int(palette.cornerRadius.rounded()))
    }

    /// `tileCorners`, but switchable: a containerless tile keeps the exact same
    /// modifier chain (and therefore the same widget tree — conditional view
    /// structure here has broken the whole board before) with a 0 radius, so
    /// nothing is clipped and nothing is restructured.
    func tileCorners(_ palette: ThemeToSCUIPalette, rounded: Bool) -> some View {
        cornerRadius(rounded ? Int(palette.cornerRadius.rounded()) : 0)
    }
}
