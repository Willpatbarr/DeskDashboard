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

    /// `tapUnlessDragged`, for a view that ALSO recognises a long press: the tap
    /// is additionally suppressed when this press already became a hold.
    ///
    /// Both signals ride GTK's `released`, so their order is not determined —
    /// leaving it to `HoldGate`'s echo window would let a long press focus the
    /// session about half a second after it opened the panel. One box owns the
    /// whole press instead: `press` clears the flag, `onHold` sets it, `release`
    /// checks it. Nothing about the decision depends on which signal lands first.
    ///
    /// `onHold` is called IN ADDITION to whatever long-press gesture the caller
    /// attached — it exists to mark the box, not to replace that gesture.
    ///
    /// `onRelease` is what `onPressRelease` would have carried, and it is folded
    /// in here rather than chained. That is not tidiness: both modifiers claim
    /// `GestureClick.released`, both re-apply on `.afterUpdate`, and the later
    /// one in the chain simply overwrites the earlier. Chaining them meant
    /// `onPressRelease` won and the tap this modifier fires from `released`
    /// never ran at all — a card that could be held but never tapped, and only
    /// on the panel, since the whole file is a no-op off GTK.
    ///
    /// Order inside `release` matters too: the tap goes first, then the release.
    /// `HoldGate.pressEnded` cancels a pending tap, so running it first would
    /// swallow the very tap being delivered.
    ///
    /// No-op off GTK, exactly like `tapUnlessDragged`: the Mac dev build keeps
    /// press-to-fire, so the long press there is arbitrated by `HoldGate` alone.
    func tapUnlessDraggedOrHeld(
        slop: Double,
        onHold: @escaping () -> Void,
        onTap: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        #if canImport(GtkBackend)
            let box = DragSlopBox(slop: slop, action: onTap)
            let release = ReleaseBox(onRelease)
            return inspect(.afterUpdate) { (widget: Gtk.Widget) in
                for controller in widget.eventControllers {
                    if let click = controller as? GestureClick {
                        click.pressed = { _, nPress, x, y in box.press(nPress: nPress, x: x, y: y) }
                        click.released = { _, _, x, y in
                            box.release(x: x, y: y)
                            release.action()
                        }
                    }
                    // The long press marks the box so the release that follows
                    // knows this press was a hold, not a tap.
                    if let press = controller as? GestureLongPress {
                        press.pressed = { _, _, _ in
                            box.markHeld()
                            onHold()
                        }
                    }
                }
            }
        #else
            _ = onHold
            _ = onRelease
            return self
        #endif
    }
}

/// Carries the release action into `inspect`'s `@Sendable` closure — same
/// reason `PressReleaseGTK` boxes its own.
private final class ReleaseBox: @unchecked Sendable {
    let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }
}

/// Remembers where a press landed and decides whether the release counts as a
/// tap. Its own type (rather than captured vars) so the state survives inside
/// `inspect`'s `@Sendable` closure.
private final class DragSlopBox: @unchecked Sendable {
    private let slop: Double
    private let action: () -> Void
    private var origin: (x: Double, y: Double)?
    /// This press already became a long press, so its release is not a tap.
    ///
    /// Cleared on every `press`, which is the only reason one flag is enough:
    /// GTK delivers `GestureClick.pressed` at the start of every press, hold or
    /// not, so the flag can never leak from one press into the next.
    private var heldThisPress = false

    init(slop: Double, action: @escaping () -> Void) {
        self.slop = slop
        self.action = action
    }

    func press(nPress: Int, x: Double, y: Double) {
        // Only a first press arms the tap; a double-click's second press is not
        // a new tap on this board.
        origin = nPress == 1 ? (x, y) : nil
        heldThisPress = false
    }

    /// The long press fired for the press currently down.
    func markHeld() {
        heldThisPress = true
    }

    func release(x: Double, y: Double) {
        guard let origin else { return }
        self.origin = nil
        guard !heldThisPress else { return }
        let dx = x - origin.x
        let dy = y - origin.y
        guard (dx * dx + dy * dy).squareRoot() <= slop else { return }
        action()
    }
}
