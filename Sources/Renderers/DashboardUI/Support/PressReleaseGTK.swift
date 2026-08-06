// PressReleaseGTK.swift — Observes button release on GTK, which SwiftCrossUI omits.

import SwiftCrossUI

#if canImport(GtkBackend)
    import Gtk
    import GtkBackend
#endif

// Second file allowed to `import Gtk`, for the same reason as
// `TextToGTKTracking.swift`: Gtk exports its own `Color`/`Font`, so the import has
// to stay quarantined or every other file's type lookup turns ambiguous.

extension View {
    /// Runs `action` when a press on this view ends.
    ///
    /// SwiftCrossUI's gesture API reports only that a gesture *fired* — there's no
    /// release or end event — which is not enough to repeat something for as long
    /// as a finger is down. GTK does expose it: the primary `GestureClick` the
    /// backend already attached has a `released` signal that SwiftCrossUI leaves
    /// unset, so this fills it in rather than adding a competing controller.
    ///
    /// Re-applied on `.afterUpdate` deliberately. Widgets are reused across
    /// re-renders, so a closure captured once at create time could outlive the tile
    /// it belonged to and fire for the wrong widget after an arrangement switch.
    ///
    /// Re-attaching is not enough to survive a widget being REPLACED, though. If a
    /// layout adds or removes a node while a finger is down, GTK rebuilds the widgets
    /// below it and cancels the gesture on the one being held: this handler is duly
    /// re-attached to the new widget, but that widget never saw a press, so no
    /// release is ever emitted and a repeat driven by it runs forever. Layouts must
    /// therefore keep their node structure constant — see `lifeCounter`, which draws
    /// absent children as empty text for exactly this reason.
    ///
    /// No-op off GTK, so the Mac dev build simply has no auto-repeat.
    func onPressRelease(_ action: @escaping () -> Void) -> some View {
        #if canImport(GtkBackend)
            // Boxed because `inspect`'s closure is `@Sendable`: a plain closure
            // can't be captured there (Linux strict concurrency), the same reason
            // `HoldGate` boxes what it hands to a `Timer`.
            let box = ReleaseActionBox(action)
            return inspect(.afterUpdate) { (widget: Gtk.Widget) in
                for controller in widget.eventControllers {
                    guard let click = controller as? GestureClick else { continue }
                    click.released = { _, _, _, _ in box.action() }
                }
            }
        #else
            return self
        #endif
    }
}

/// Carries the release action into `inspect`'s `@Sendable` closure.
private final class ReleaseActionBox: @unchecked Sendable {
    let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }
}
