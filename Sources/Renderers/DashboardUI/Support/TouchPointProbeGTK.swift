// TouchPointProbeGTK.swift — Reports where the last press landed, so a popover can sit beside it.

import SwiftCrossUI

#if canImport(GtkBackend)
    import Gtk
    import GtkBackend
#endif

// Sixth and last file allowed to `import Gtk`, for the same reason as
// `TextToGTKTracking.swift`, `PressReleaseGTK.swift`, `TileBorderGTK.swift` and
// `TapUnlessDraggedGTK.swift`: Gtk exports its own `Color`/`Font`, so the import
// stays quarantined or every other file's type lookup turns ambiguous.

extension View {
    /// Reports the position of every press on this view, in ITS coordinate
    /// space, before any descendant gets a say.
    ///
    /// Exists because nothing else in this stack can tell a layout where one of
    /// its nodes ended up: `WidgetView` has no position, SwiftCrossUI's
    /// `GeometryProxy` carries a size with no origin, and a card inside a
    /// `.scroll` moves out from under any guess made from its slot index. The
    /// touch point is the one location that IS obtainable, and a card is about a
    /// column wide, so beside the finger reads as beside the card.
    ///
    /// Unlike its neighbours this ADDS a controller rather than re-pointing one
    /// the backend already attached, which makes idempotence the whole problem:
    /// `inspect(.afterUpdate)` runs on every update, and a controller added per
    /// update would pile up for the life of the process. The widget's `name` is
    /// used as a one-shot marker — it is the same property `Widget.tag(as:)`
    /// writes, and nothing else on this view sets it.
    ///
    /// `.capture` phase, so it observes the press on the way DOWN — before a
    /// card, a scrolled window, or anything else claims the sequence — and it
    /// never claims anything itself, so it cannot perturb the gestures below it.
    /// That ordering is what makes the point fresh: the press that opens a menu
    /// is seen here before the card's own handler runs.
    ///
    /// No-op off GTK. The AppKit dev build reports no touch point at all, which
    /// is exactly why `LayerAnchor.lastTouch` documents a fallback.
    func touchPointProbe(_ record: @escaping (Double, Double) -> Void) -> some View {
        #if canImport(GtkBackend)
            // Boxed because `inspect`'s closure is `@Sendable` — same reason
            // `onPressRelease` and `tapUnlessDragged` box theirs.
            let box = TouchRecordBox(record)
            return inspect(.afterUpdate) { (widget: Gtk.Widget) in
                guard widget.name != Self.touchProbeMarker else { return }
                widget.name = Self.touchProbeMarker

                let probe = GestureClick()
                probe.propagationPhase = .capture
                probe.pressed = { _, _, x, y in box.record(x, y) }
                widget.addEventController(probe)
            }
        #else
            _ = record
            return self
        #endif
    }

    /// Marks a widget as already carrying a probe. A plain constant rather than
    /// anything clever: it only has to be a string nothing else writes.
    fileprivate static var touchProbeMarker: String { "dd-touch-probe" }
}

#if canImport(GtkBackend)
    /// Carries the callback into `inspect`'s `@Sendable` closure.
    private final class TouchRecordBox: @unchecked Sendable {
        let record: (Double, Double) -> Void

        init(_ record: @escaping (Double, Double) -> Void) {
            self.record = record
        }
    }
#endif
