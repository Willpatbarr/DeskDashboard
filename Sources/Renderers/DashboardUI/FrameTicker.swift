import Foundation

/// A short-lived repeating callback used to hand-animate UI state.
///
/// SwiftCrossUI has **no animation system** — no `withAnimation`, no
/// `.animation()`, no transitions — so anything that moves has to be stepped by
/// hand: mutate published state every frame and let the normal re-render draw it.
///
/// It deliberately uses Foundation's `Timer`, the same primitive as
/// `TimerDashboardClock`, because that is the one scheduling mechanism proven to
/// fire on the Pi. GTK runs its own main loop and does **not** drain libdispatch's
/// main queue, so `DispatchQueue.main.asyncAfter` is not a safe substitute there.
///
/// Lives in its own file on purpose: `DashboardModel` cannot `import Foundation`
/// without making `ObservableObject`/`Published` ambiguous against SwiftCrossUI's
/// versions of those names.
final class FrameTicker: @unchecked Sendable {
    private var timer: Timer?

    var isRunning: Bool { timer != nil }

    /// Starts calling `onFrame` every `interval` seconds until `stop()`. Any
    /// previous run is cancelled first, so a re-tap mid-animation restarts
    /// cleanly rather than stacking timers.
    func start(
        interval: Double,
        onFrame: @escaping () -> Void
    ) {
        stop()
        let box = FrameHandlerBox(onFrame)
        timer = Timer.scheduledTimer(
            withTimeInterval: max(interval, 0.001),
            repeats: true
        ) { _ in
            box.onFrame()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

private final class FrameHandlerBox: @unchecked Sendable {
    let onFrame: () -> Void

    init(_ onFrame: @escaping () -> Void) {
        self.onFrame = onFrame
    }
}


