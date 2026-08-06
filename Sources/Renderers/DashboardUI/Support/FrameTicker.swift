// FrameTicker.swift — Timer that hand-steps animations, plus the `DD_UI_LOG` logging helper.

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

    /// Wall-clock gaps between delivered frames, for the `DD_UI_LOG` summary.
    /// Requesting a cadence proves nothing — the panel decides what it can
    /// actually paint, and this is how that gets measured instead of assumed.
    private var requested: Double = 0
    private var lastFiredAt: Double?
    private var gaps: [Double] = []

    var isRunning: Bool { timer != nil }

    /// Starts calling `onFrame` every `interval` seconds until `stop()`. Any
    /// previous run is cancelled first, so a re-tap mid-animation restarts
    /// cleanly rather than stacking timers.
    func start(
        interval: Double,
        onFrame: @escaping () -> Void
    ) {
        stop()
        requested = max(interval, 0.001)
        lastFiredAt = nil
        gaps = []
        let box = FrameHandlerBox(onFrame)
        timer = Timer.scheduledTimer(
            withTimeInterval: requested,
            repeats: true
        ) { [weak self] _ in
            self?.recordFrame()
            box.onFrame()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        reportCadence()
    }

    private func recordFrame() {
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastFiredAt { gaps.append(now - last) }
        lastFiredAt = now
    }

    /// One line per completed run: what was asked for versus what arrived.
    private func reportCadence() {
        guard gaps.count > 1 else { return }
        let mean = gaps.reduce(0, +) / Double(gaps.count)
        let worst = gaps.max() ?? 0
        let best = gaps.min() ?? 0
        func ms(_ seconds: Double) -> String { String(Int((seconds * 1000).rounded())) }
        UILog.write(
            "FRAMES n=\(gaps.count) asked=\(ms(requested))ms "
                + "mean=\(ms(mean))ms min=\(ms(best))ms max=\(ms(worst))ms "
                + "≈\(Int((1 / max(mean, 0.001)).rounded()))fps"
        )
        gaps = []
    }
}

private final class FrameHandlerBox: @unchecked Sendable {
    let onFrame: () -> Void

    init(_ onFrame: @escaping () -> Void) {
        self.onFrame = onFrame
    }
}

/// Logs a line to stderr, but only the *first* time a given `key`'s message
/// changes — so a per-render call site logs once instead of every frame.
///
/// This exists because the layout can only be inspected on the device: the Pi's
/// panel is the only place the real geometry happens, and there's no way to
/// screenshot it from a dev machine. Printing the numbers the layout computed
/// turns "it looks clipped" into an arithmetic problem.
enum UILog {
    nonisolated(unsafe) private static var seen: [String: String] = [:]
    private static let lock = NSLock()

    static func once(_ key: String, _ message: @autoclosure () -> String) {
        guard ProcessInfo.processInfo.environment["DD_UI_LOG"] == "1" else { return }
        let text = message()
        lock.lock()
        let isNew = seen[key] != text
        if isNew { seen[key] = text }
        lock.unlock()
        guard isNew else { return }
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    /// Unconditional counterpart to `once`, for values that are *supposed* to
    /// repeat — a per-run measurement, where every run is a new data point.
    static func write(_ message: @autoclosure () -> String) {
        guard ProcessInfo.processInfo.environment["DD_UI_LOG"] == "1" else { return }
        FileHandle.standardError.write(Data((message() + "\n").utf8))
    }
}


