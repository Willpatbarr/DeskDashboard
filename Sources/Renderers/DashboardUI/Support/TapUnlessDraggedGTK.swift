// TapUnlessDraggedGTK.swift — Tap-on-release with drag slop, so scrolling doesn't fire taps.

import SwiftCrossUI

#if canImport(GtkBackend)
    import Gtk
    import GtkBackend
#endif

// Fourth and last file allowed to `import Gtk`, for the same reason as
// `TextToGTKTracking.swift`, `PressReleaseGTK.swift` and `TileBorderGTK.swift`:
// Gtk exports its own `Color`/`Font`, so the import stays quarantined or every
// other file's type lookup turns ambiguous.

extension View {
    /// Fires `action` when a press on this view ENDS, and only if the finger
    /// stayed within `slop` points of where it landed.
    ///
    /// SwiftCrossUI fires `onTapGesture` from `GestureClick.pressed` — on touch
    /// DOWN. Inside a scroll container that is unusable: the tap has already
    /// fired before GTK can tell a tap from the start of a drag, so every scroll
    /// gesture also activated whatever card it began on (measured on the panel:
    /// scrolling a session column focused the row you pushed off from, every
    /// time). No amount of gesture arbitration can retract an action that
    /// already ran, so the timing has to move instead.
    ///
    /// This overrides the backend's own handlers on the gesture it already
    /// attached, rather than adding a competing controller: `pressed` only
    /// records the origin, and `released` decides. A gesture GTK cancels
    /// (because the scrolled window claimed the sequence) never emits `released`
    /// at all, which is exactly the outcome we want.
    ///
    /// Re-applied on `.afterUpdate` because SwiftCrossUI re-sets `pressed` on
    /// every update — same ordering `cssBorder` and `onPressRelease` depend on.
    ///
    /// No-op off GTK: the Mac dev build keeps the backend's press-to-fire
    /// behaviour, which is fine with a mouse and no touch scrolling.
    func tapUnlessDragged(slop: Double, _ action: @escaping () -> Void) -> some View {
        #if canImport(GtkBackend)
            // Boxed because `inspect`'s closure is `@Sendable` — same reason
            // `onPressRelease` boxes its action.
            let box = DragSlopBox(slop: slop, action: action)
            return inspect(.afterUpdate) { (widget: Gtk.Widget) in
                for controller in widget.eventControllers {
                    guard let click = controller as? GestureClick else { continue }
                    click.pressed = { _, nPress, x, y in box.press(nPress: nPress, x: x, y: y) }
                    click.released = { _, _, x, y in box.release(x: x, y: y) }
                }
            }
        #else
            return self
        #endif
    }
}

/// Remembers where a press landed and decides whether the release counts as a
/// tap. Its own type (rather than captured vars) so the state survives inside
/// `inspect`'s `@Sendable` closure.
private final class DragSlopBox: @unchecked Sendable {
    private let slop: Double
    private let action: () -> Void
    private var origin: (x: Double, y: Double)?

    init(slop: Double, action: @escaping () -> Void) {
        self.slop = slop
        self.action = action
    }

    func press(nPress: Int, x: Double, y: Double) {
        // Only a first press arms the tap; a double-click's second press is not
        // a new tap on this board.
        origin = nPress == 1 ? (x, y) : nil
    }

    func release(x: Double, y: Double) {
        guard let origin else { return }
        self.origin = nil
        let dx = x - origin.x
        let dy = y - origin.y
        guard (dx * dx + dy * dy).squareRoot() <= slop else { return }
        action()
    }
}
