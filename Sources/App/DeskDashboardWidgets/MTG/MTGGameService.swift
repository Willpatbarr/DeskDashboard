// MTGGameService.swift — MTG DATA layer: shared life totals and turn number.

import DashboardKit
import Foundation

// MTG game state lives in a service, not in the widgets, for two reasons:
// widgets are value types rebuilt every tick so state on `self` wouldn't
// survive, and the turn counter is *shared* — every life widget and the turn
// widget read the same game.

/// Source of truth for a game in progress.
public protocol MTGGameService: AnyObject {
    /// Life for one player slot, by widget id.
    func life(for player: String) -> Int
    func adjustLife(for player: String, by delta: Int)
    /// Back to the format's starting total.
    func resetLife(for player: String)

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
    /// Commander's starting total, and what a reset returns to.
    public static let startingLife = 40

    private let lock = NSLock()
    private var lifeByPlayer: [String: Int] = [:]
    private var currentTurn = 0

    public init() {}

    public func life(for player: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return lifeByPlayer[player] ?? Self.startingLife
    }

    public func adjustLife(for player: String, by delta: Int) {
        lock.lock()
        defer { lock.unlock() }
        lifeByPlayer[player] = (lifeByPlayer[player] ?? Self.startingLife) + delta
    }

    public func resetLife(for player: String) {
        lock.lock()
        defer { lock.unlock() }
        lifeByPlayer[player] = Self.startingLife
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
