// HoldGate.swift — Decides tap vs hold, and repeats a held action until release.

import Foundation

/// Arbitrates the gestures on one region: a quick press is a tap, a long press is
/// a hold that repeats until the finger lifts.
///
/// GTK gives no press/release pair through SwiftCrossUI's gesture API:
/// `onTapGesture(.primary)` is wired to `GestureClick::pressed`, which fires the
/// instant the button goes down, and `GestureLongPress` fires later if the finger
/// stays. So a hold delivers BOTH actions — measured on the panel, holding `+`
/// moved life by 11 rather than 10.
///
/// Hence: a tap on a hold-capable region is **withheld** until the press resolves,
/// and cancelled if a hold follows. Release comes from `View.onPressRelease` (see
/// `PressReleaseGTK.swift`), which fills in the `released` signal SwiftCrossUI
/// leaves unset.
///
/// The tap then lands **on release** — about as fast as the finger lifts — and
/// `holdWindow` is only the fallback for backends that deliver no release at all.
/// Emitting on the timer in every case cost a flat 550ms of input lag on every tap,
/// which is what "super laggy" turned out to mean; measured after the change, press
/// to emit was 2ms.
///
/// Measured on the panel with `DD_UI_LOG=1`, a touchscreen press delivers exactly
/// one tap, one long press, one repeat per interval and one release. There is no
/// duplicate gesture and no emulated-pointer echo on this hardware — an earlier note
/// here claimed otherwise and was wrong. The echo guards below are cheap insurance
/// keyed on *time* rather than on gesture state (which any interleaved event can
/// clear), not a workaround for something known to arrive.
///
/// Rejected alternatives, both of which would diverge between backends: having the
/// hold apply +9 to "top up" the tap, and suppressing the tap *after* a hold (which
/// assumes the tap arrives second — true on AppKit, false on GTK).
///
/// `@unchecked Sendable` with boxed closures, mirroring `FrameTicker`: `Timer`'s
/// callback is `@Sendable`, and Linux strict concurrency rejects capturing a plain
/// closure or `self` inside it. The Mac build accepts it, so this only shows up
/// when building for the Pi.
final class HoldGate: @unchecked Sendable {
    /// Slightly above GTK's long-press threshold, which it derives from the
    /// double-click time (~500ms by default).
    private static let holdWindow = 0.55

    /// Gap between repeats while held. Slow enough to stop on the number you want
    /// — at 10 life per step, faster runs away from you.
    private static let repeatInterval = 0.45

    /// Most pulses one press may deliver, ≈9s of holding — far longer than any real
    /// hold, short enough to bound the damage.
    ///
    /// A release is not guaranteed to arrive. GTK stops delivering `released` if the
    /// widget under the finger is rebuilt mid-press, which any layout that changes
    /// SHAPE on state will cause. That is a layout bug and is fixed where it happens,
    /// but the failure mode here is a life total draining forever on a kiosk nobody
    /// is holding, so the repeat refuses to outlive a plausible press regardless.
    private static let maxRepeats = 20

    /// A gesture arriving this soon after one of the same press belongs to that
    /// press, not to a new one. Comfortably longer than the sub-millisecond gap
    /// between a touch event and its emulated pointer, and far shorter than any
    /// deliberate second press — which, being deferred by `holdWindow`, could not
    /// have registered separately anyway.
    private static let echoWindow = 0.30

    private var pendingTap: Timer?
    /// The same action `pendingTap` holds, so a release can fire it early. Whichever
    /// gets there first wins; `ActionBox` makes sure only one of them runs it.
    private var pendingTapAction: ActionBox?
    private var repeater: Timer?

    /// When the current (or most recent) hold began and ended. `-.infinity` reads as
    /// "long ago", so the first press of a run compares cleanly.
    private var holdStartedAt = -Double.infinity
    private var holdEndedAt = -Double.infinity

    private static var now: Double { ProcessInfo.processInfo.systemUptime }

    /// Emits `action` unless a hold arrives first.
    func tap(deferred: Bool, _ emit: @escaping () -> Void) {
        let time = Self.now
        UILog.write(Self.stamp(time, "tap deferred=\(deferred)"))

        // The duplicate press for a finger that is already holding, or has just let
        // go. Letting it through would undo the hold twice over: `pressEnded()`
        // below frees the guard in `holdBegan`, so the duplicate long press that
        // follows starts a SECOND repeat — the two interleave and read as one
        // double-sized step — and the tap it defers outlives the finger, landing
        // once more after release. Both halves of the reported symptom.
        if time - holdStartedAt < Self.echoWindow || time - holdEndedAt < Self.echoWindow {
            UILog.write(Self.stamp(time, "tap dropped: echo of a hold"))
            return
        }

        // A fresh press means the previous one ended, even if its release never
        // arrived. Without this a missed release would leave a repeat running and
        // block every later hold. The echo check above runs first so that recovery
        // can't fire for what is really the same press.
        cancelRepeat()

        guard deferred else {
            emit()
            return
        }

        // The duplicate press for a finger that is still waiting to become a hold.
        // The deferred tap already scheduled is the one to keep; rescheduling would
        // only push it later. Tested for validity, not for nil: a one-shot `Timer`
        // that has already fired stays referenced, and reading it as "still pending"
        // would swallow every later tap.
        if pendingTap?.isValid == true {
            UILog.write(Self.stamp(time, "tap dropped: echo of a pending tap"))
            return
        }

        // The tap normally lands on RELEASE (see `pressEnded()`), typically within
        // ~100ms. This timer is only the fallback for when no release arrives —
        // every backend but GTK, where `onPressRelease` is a no-op. Waiting the full
        // window on every tap is what made the panel feel laggy: a half-second of
        // nothing before a `+` moved.
        let box = ActionBox(emit)
        pendingTapAction = box
        pendingTap = Timer.scheduledTimer(withTimeInterval: Self.holdWindow, repeats: false) { _ in
            guard box.fireOnce() else { return }
            UILog.write(Self.stamp(Self.now, "tap emitted — fallback timer"))
        }
    }

    /// Cancels the tap this same press already produced, fires the hold once, then
    /// keeps firing it until `pressEnded()`.
    func holdBegan(_ emit: @escaping () -> Void) {
        let time = Self.now
        UILog.write(Self.stamp(time, "hold began"))

        // The second long press for one finger — see the note on the type. Guarding
        // by elapsed time rather than by `repeater == nil` is the point: a press or
        // release event arriving between the two long presses clears that state, and
        // the guard then silently stops guarding.
        if time - holdStartedAt < Self.echoWindow {
            UILog.write(Self.stamp(time, "hold dropped: echo of a hold"))
            return
        }

        // Retire a repeat whose release went missing, so it can't outlive this one.
        cancelRepeat()
        holdStartedAt = time

        // This press is a hold, so the tap it also produced is cancelled outright —
        // both the fallback timer and the action the release would otherwise fire.
        pendingTap?.invalidate()
        pendingTap = nil
        pendingTapAction = nil

        emit()
        let box = RepeatBox(emit)
        repeater = Timer.scheduledTimer(withTimeInterval: Self.repeatInterval, repeats: true) { timer in
            box.delivered += 1
            guard box.delivered <= Self.maxRepeats else {
                // Invalidated through the timer the callback is handed, because the
                // gate's own `repeater` can't be touched from a `@Sendable` closure.
                timer.invalidate()
                UILog.write(Self.stamp(Self.now, "repeat capped — no release ever arrived"))
                return
            }
            UILog.write(Self.stamp(Self.now, "hold repeated"))
            box.action()
        }
    }

    /// The finger lifted. Safe to call for presses that never became holds.
    ///
    /// Kept distinct from `cancelRepeat()` so that a diagnostic run can tell a real
    /// GTK release from this type's own internal recovery. Logging them alike once
    /// cost an hour: `tap` and `holdBegan` both cancel a stale repeat, so the log
    /// showed a "release" a millisecond after every press and every hold, and read
    /// exactly like GTK double-delivering events for one finger. It was this file
    /// logging itself.
    func pressEnded() {
        UILog.write(Self.stamp(Self.now, "released"))

        // A press that never became a hold is a tap, and now it's over — so emit it
        // now rather than serving out the rest of the fallback window. This is the
        // whole reason the release signal was worth fishing out of GTK: it turns a
        // flat 550ms of input lag into roughly the time the finger was actually down.
        // `cancelRepeat()` below is a no-op in that case; when a hold DID run,
        // `holdBegan` already cleared the pending tap, so nothing fires here.
        if let pending = pendingTapAction, pending.fireOnce() {
            UILog.write(Self.stamp(Self.now, "tap emitted — on release"))
        }
        pendingTap?.invalidate()
        pendingTap = nil
        pendingTapAction = nil

        cancelRepeat()
    }

    /// Stops a running repeat, and with it any tap deferred while it ran.
    private func cancelRepeat() {
        guard repeater != nil else { return }
        let time = Self.now
        UILog.write(Self.stamp(time, "repeat cancelled"))

        repeater?.invalidate()
        repeater = nil
        holdEndedAt = time

        // A tap deferred while the hold was running must not survive the finger
        // lifting. Only cancelled here, on a press that was actually holding — a
        // plain tap is emitted by `pressEnded()` before this runs.
        pendingTap?.invalidate()
        pendingTap = nil
        pendingTapAction = nil
    }

    /// One log line, timestamped on the same clock as every other, so `journalctl`
    /// shows the real event order and spacing. Costs nothing unless `DD_UI_LOG=1`.
    private static func stamp(_ time: Double, _ event: String) -> String {
        // `%@` is not dependable in swift-corelibs-foundation's `String(format:)`,
        // so only the Double goes through it.
        "holdgate \(String(format: "%8.3f", time)) \(event)"
    }
}

/// Carries an action into a timer's `@Sendable` callback, and runs it at most once.
///
/// A deferred tap has two callers racing to emit it — the release that ends the
/// press, and the fallback timer for when no release comes — so the box, not the
/// callers, is what guarantees one emit. No lock: both arrive on the run loop.
private final class ActionBox: @unchecked Sendable {
    private let action: () -> Void
    private var hasFired = false

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    /// Runs the action and returns `true` the first time; does nothing after that.
    @discardableResult
    func fireOnce() -> Bool {
        guard !hasFired else { return false }
        hasFired = true
        action()
        return true
    }
}

/// `ActionBox` plus the running pulse count, so a repeat can cap itself. Mutable
/// state a `@Sendable` closure may touch has to live in a reference like this; the
/// timer's callbacks are serialised on the run loop, so the counter needs no lock.
private final class RepeatBox: @unchecked Sendable {
    let action: () -> Void
    var delivered = 0

    init(_ action: @escaping () -> Void) {
        self.action = action
    }
}
