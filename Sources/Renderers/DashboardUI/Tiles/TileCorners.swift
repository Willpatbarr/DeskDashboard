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

    /// Outlines a tile in the theme's `border` colour.
    ///
    /// Drawn as CSS on the tile's own widget — see `cssBorder`, which explains at
    /// length why the obvious `.overlay` of a stroked shape cannot be used here.
    /// A theme with no border passes `nil` and nothing is drawn, and a containerless
    /// tile does the same.
    func tileBorder(_ palette: ThemeToSCUIPalette, rounded: Bool) -> some View {
        cssBorder(
            hex: rounded ? palette.borderHex : nil,
            width: palette.borderWidth,
            radius: rounded ? palette.cornerRadius : 0
        )
    }

    /// `tileBorder` at an explicit radius, for chrome that isn't a tile — the
    /// switcher pills are capsules, so their radius is half their height.
    func pillBorder(_ palette: ThemeToSCUIPalette, radius: Double) -> some View {
        cssBorder(hex: palette.borderHex, width: palette.borderWidth, radius: radius)
    }

    /// `pillBorder` that is never absent: falls back to the accent when the theme
    /// defines no border colour.
    ///
    /// For the Edit button, whose deselected state is an OUTLINE with no fill —
    /// on a theme with no border and no track there'd be nothing left to see.
    func alwaysPillBorder(_ palette: ThemeToSCUIPalette, radius: Double) -> some View {
        cssBorder(
            hex: palette.borderHex ?? palette.accentHex,
            width: palette.borderWidth,
            radius: radius
        )
    }
}
