// MTGGameService.swift — MTG DATA layer: shared life totals and turn number.

import DashboardKit
import Foundation

// MTG game state lives in a service, not in the widgets, for two reasons:
// widgets are value types rebuilt every tick so state on `self` wouldn't
// survive, and the turn counter is *shared* — every life widget and the turn
// widget read the same game.

/// Source of truth for a game in progress.
public protocol MTGGameService: AnyObject {
    /// The format's starting total, and what `resetLife(for:)` returns to.
    ///
    /// Exposed because a widget has to know whether a seat has anything to reset —
    /// the reset affordance only appears once life has moved off this number.
    var startingLife: Int { get }

    /// Life for one player slot, by widget id.
    func life(for player: String) -> Int
    func adjustLife(for player: String, by delta: Int)
    /// Back to the format's starting total.
    func resetLife(for player: String)

    /// Net change across the run of adjustments still in progress for this seat, or
    /// `nil` once it has settled (or netted back to zero).
    ///
    /// This is what makes a hit readable: tapping `−1` four times shows `−4` beside
    /// the total, so you can see what just happened without having remembered the
    /// number before it. It expires on its own — no caller has to clear it.
    func recentLifeChange(for player: String) -> Int?

    var turn: Int { get }
    func advanceTurn()
    func resetTurn()
}

public enum MTGGameServiceKeys {
    public static let game = ServiceKey<any MTGGameService>("mtgGame")
}

/// In-memory game state, thread safe because taps arrive on the UI thread while
/// widgets render from the tick.
///
/// Unlike the old `MTGScreen`, whose counters used view-local `@State`, this
/// survives switching arrangements — leaving MTG and coming back no longer wipes
/// a game in progress. Resetting is now explicit.
public final class InMemoryMTGGameService: MTGGameService, @unchecked Sendable {
    /// Commander's starting total, and what a reset returns to. Kept `static` so
    /// callers with no instance to hand (tests, defaults above) can name it; the
    /// instance property below is the same number reached through the protocol.
    public static let startingLife = 40

    public var startingLife: Int { Self.startingLife }

    /// How long a run of adjustments keeps showing its running total. Long enough to
    /// read after you stop tapping, short enough that it's gone by the next turn.
    public static let defaultChangeWindow: Double = 3

    private let lock = NSLock()
    private var lifeByPlayer: [String: Int] = [:]
    private var currentTurn = 0

    /// Per seat: the run's net change, and when it was last added to.
    private var pendingChange: [String: (total: Int, at: Double)] = [:]
    private let changeWindow: Double

    /// Monotonic, so it can't be dragged backwards by a clock correction the way
    /// wall-clock time can — the same source `HoldGate` times gestures with.
    private var now: Double { ProcessInfo.processInfo.systemUptime }

    /// - Parameter changeWindow: seconds a run of adjustments stays visible.
    ///   Injectable so a test can pin the expiry instead of sleeping through it.
    public init(changeWindow: Double = InMemoryMTGGameService.defaultChangeWindow) {
        self.changeWindow = changeWindow
    }

    public func life(for player: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return lifeByPlayer[player] ?? Self.startingLife
    }

    public func adjustLife(for player: String, by delta: Int) {
        lock.lock()
        defer { lock.unlock() }
        lifeByPlayer[player] = (lifeByPlayer[player] ?? Self.startingLife) + delta

        // Keep adding to the run in progress; start a fresh one if the last change
        // has already expired. Timed from the last adjustment rather than the first,
        // so a long series of taps stays on screen while it's still being tapped.
        let time = now
        let running = pendingChange[player].map { time - $0.at < changeWindow ? $0.total : 0 } ?? 0
        pendingChange[player] = (running + delta, time)
    }

    public func resetLife(for player: String) {
        lock.lock()
        defer { lock.unlock() }
        lifeByPlayer[player] = Self.startingLife
        // Reset is not a "change of −7" — it discards the run rather than logging one.
        pendingChange[player] = nil
    }

    public func recentLifeChange(for player: String) -> Int? {
        lock.lock()
        defer { lock.unlock() }
        guard let change = pendingChange[player],
              now - change.at < changeWindow,
              // +1 then −1 leaves nothing worth reporting.
              change.total != 0
        else { return nil }
        return change.total
    }

    public var turn: Int {
        lock.lock()
        defer { lock.unlock() }
        return currentTurn
    }

    public func advanceTurn() {
        lock.lock()
        defer { lock.unlock() }
        currentTurn += 1
    }

    public func resetTurn() {
        lock.lock()
        defer { lock.unlock() }
        currentTurn = 0
    }
}
