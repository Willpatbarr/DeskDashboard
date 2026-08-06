// HoldGate.swift — Decides whether a press became a tap or a hold.

import Foundation

/// Arbitrates between a tap and a long press on the same region.
///
/// Needed because GTK gives no "press began / press ended" pair to reason from:
/// `onTapGesture(.primary)` is wired to `GestureClick::pressed`, which fires the
/// instant the button goes down, and `GestureLongPress` fires later if the finger
/// stays. So a hold delivers BOTH actions — measured on the panel, holding `+`
/// moved life by 11 rather than 10.
///
/// The tap therefore can't be judged when it arrives; it has to wait long enough
/// to see whether a hold follows. A held press emits only the hold action; a quick
/// press emits only the tap, `holdWindow` later.
///
/// Rejected alternatives, both of which would diverge between backends: having the
/// hold apply +9 to "top up" the tap (assumes both gestures always fire, and in a
/// fixed order), and suppressing the tap *after* a hold (assumes the tap arrives
/// second, which is true on GTK and not on AppKit).
///
/// Only regions that declare a hold pay this latency — a tap with no hold action
/// is emitted immediately, so nothing else in the app feels slower.
///
/// `@unchecked Sendable` with the emitted closure boxed, mirroring `FrameTicker`:
/// `Timer`'s callback is `@Sendable`, and on Linux strict concurrency rejects
/// capturing a plain closure or `self` inside it. The Mac build accepts it, so this
/// only shows up when building for the Pi.
final class HoldGate: @unchecked Sendable {
    /// Slightly above GTK's long-press threshold, which it derives from the
    /// double-click time (~500ms by default).
    private static let holdWindow = 0.55

    private var pendingTap: Timer?

    /// Emits `action` unless a hold arrives first.
    func tap(deferred: Bool, _ emit: @escaping () -> Void) {
        guard deferred else {
            emit()
            return
        }
        pendingTap?.invalidate()
        // Box the closure and capture nothing else: the timer callback is
        // `@Sendable`, so neither `emit` nor `self` may be captured directly.
        let box = TapActionBox(emit)
        pendingTap = Timer.scheduledTimer(
            withTimeInterval: Self.holdWindow,
            repeats: false
        ) { _ in
            box.action()
        }
    }

    /// Cancels the tap this press already produced, then emits the hold.
    func hold(_ emit: @escaping () -> Void) {
        pendingTap?.invalidate()
        pendingTap = nil
        emit()
    }
}

/// Carries a tap's action into the timer's `@Sendable` callback.
private final class TapActionBox: @unchecked Sendable {
    let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }
}
