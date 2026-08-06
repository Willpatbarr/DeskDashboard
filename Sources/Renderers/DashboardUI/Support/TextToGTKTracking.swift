// TextToGTKTracking.swift — Translation: GTK CSS letter-spacing on a `Text`; only file importing Gtk.

import SwiftCrossUI

// This file is the ONLY place in DashboardUI that imports Gtk: the Gtk module
// exports its own `Color`, `Font`, etc., which make unqualified type lookup
// ambiguous against SwiftCrossUI's in any file that imports both (this broke
// TileView on the Pi). Keeping the import quarantined here keeps the rest of
// the renderer readable.

#if canImport(GtkBackend)
    import Gtk
    import GtkBackend

    extension Text {
        /// Applies real negative letter-spacing to this text run.
        ///
        /// SwiftCrossUI exposes no tracking API (`Font` is size/weight/design
        /// only), but on the GTK backend `Text.inspect` hands us the underlying
        /// `Gtk.Label`, whose per-widget CSS class accepts GTK 4's
        /// `letter-spacing` property. Pango then tightens every glyph advance
        /// with kerning and side bearings intact.
        ///
        /// Two backend facts this relies on (verified in the SwiftCrossUI source):
        /// - `updateTextView` does `css.clear()` + re-set on EVERY update, and it
        ///   runs in `computeLayout`, before `commit` — so the property must be
        ///   re-applied at `.afterUpdate`, which fires after `commit`.
        /// - Layout measures the text *without* the tracking, so the label's box
        ///   stays a few px wide; GtkLabel centres its ink in that box
        ///   (xalign 0.5), so a centred clock stays visually centred.
        func displayTracking(pixels: Int) -> some View {
            inspect(.afterUpdate) { (label: Gtk.Label) in
                label.css.set(
                    property: CSSProperty(key: "letter-spacing", value: "\(pixels)px")
                )
            }
        }
    }
#else
    extension Text {
        /// No-op off GTK: the Mac dev build (AppKit) isn't the display target,
        /// so display text simply renders untracked there.
        func displayTracking(pixels: Int) -> some View { self }
    }
#endif
