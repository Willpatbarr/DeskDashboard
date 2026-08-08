// TileBorderGTK.swift — Draws a tile/pill outline as GTK CSS; one of three files importing Gtk.

import SwiftCrossUI

#if canImport(GtkBackend)
    import Gtk
    import GtkBackend

    // Third and last file allowed to `import Gtk`, for the same reason as
    // `TextToGTKTracking.swift` and `PressReleaseGTK.swift`: Gtk exports its own
    // `Color`/`Font`, so the import stays quarantined or every other file's type
    // lookup turns ambiguous.

    extension View {
        /// Outlines this view by setting CSS on its own widget.
        ///
        /// **Not an `.overlay` of a stroked shape, which is the obvious way and is a
        /// trap.** `.overlay` puts a real widget on top on this backend, and
        /// SwiftCrossUI has no `allowsHitTesting`, so the decoration swallows every
        /// tap meant for what it decorates. Measured on the panel: outlining the
        /// switcher pills made the whole header inert, and the same modifier on
        /// tiles had already made the MTG counters unresponsive — silently, because
        /// the board it was added for has no interactive tiles. `gtk_widget_set_
        /// can_target` on the shape did not help either; the overlay's container is
        /// what takes the input.
        ///
        /// A CSS border adds no widget at all, so there is nothing to intercept.
        ///
        /// `.afterUpdate` is required: SwiftCrossUI sets this widget's own
        /// background and corner radius through the same CSS block on every update,
        /// which would otherwise clear this. Same reason as `displayTracking`.
        ///
        /// **"No border" writes `none`; it does not skip the write.** Widgets are
        /// reused across re-renders, so returning early leaves whatever this set
        /// last time still on the widget. Skipping it meant switching the header to
        /// `Bare` kept the outline and merely squared its corners — chrome-less
        /// tiles drawn as hard rectangles.
        ///
        /// No-op off GTK, so the Mac dev build simply draws no outline.
        func cssBorder(hex: String?, width: Double, radius: Double) -> some View {
            let spec = hex.map { "\(max(1, Int(width.rounded())))px solid \($0)" } ?? "none"
            let corner = "\(max(0, Int(radius.rounded())))px"
            return inspect(.afterUpdate) { (widget: Gtk.Widget) in
                widget.css.set(property: CSSProperty(key: "border", value: spec))
                widget.css.set(property: CSSProperty(key: "border-radius", value: corner))
            }
        }
    }
#else
    extension View {
        func cssBorder(hex _: String?, width _: Double, radius _: Double) -> some View {
            self
        }
    }
#endif
