// ClaudeSessionsService.swift — Claude Code sessions: reading types + service protocol.

import DashboardKit
import Foundation

// MARK: - Reading

/// One Claude Code session as the Mac's AgentManager daemon reports it.
public struct ClaudeSession: Equatable, Sendable {
    /// The desktop app's session id (`local_…`) — also the focus key.
    public var id: String
    public var title: String
    public var project: String?
    /// Model slug, e.g. `claude-opus-5`.
    public var model: String?
    /// Column id assigned by the daemon's (user-configurable) column rules —
    /// e.g. `working` / `needs-you` / `idle`, but the set is open.
    public var column: String
    public var stalled: Bool
    public var askPending: Bool
    public var agentCount: Int
    public var lastActivity: String?
    public var ageSeconds: Int

    public init(
        id: String,
        title: String,
        project: String? = nil,
        model: String? = nil,
        column: String,
        stalled: Bool = false,
        askPending: Bool = false,
        agentCount: Int = 0,
        lastActivity: String? = nil,
        ageSeconds: Int = 0
    ) {
        self.id = id
        self.title = title
        self.project = project
        self.model = model
        self.column = column
        self.stalled = stalled
        self.askPending = askPending
        self.agentCount = agentCount
        self.lastActivity = lastActivity
        self.ageSeconds = ageSeconds
    }
}

/// A board column as the daemon defines it — columns are the daemon's config,
/// not this app's, so a re-shaped board needs no Pi rebuild.
public struct ClaudeSessionColumn: Equatable, Sendable {
    public var id: String
    public var label: String
    /// The column's accent (`#RRGGBB`), as the daemon's board config states it —
    /// the Pi board mirrors the web dashboard's colours, so colour is DATA here.
    public var colorHex: String?
    /// Compact columns render slimmer entries (the web board hides the activity
    /// line for these).
    public var compact: Bool

    public init(id: String, label: String, colorHex: String? = nil, compact: Bool = false) {
        self.id = id
        self.label = label
        self.colorHex = colorHex
        self.compact = compact
    }
}

/// One full push from the daemon: the column set plus every session, already
/// sorted column-major by the daemon.
public struct ClaudeSessionsReading: Equatable, Sendable {
    public var columns: [ClaudeSessionColumn]
    public var sessions: [ClaudeSession]
    public var receivedAt: Date

    public init(columns: [ClaudeSessionColumn], sessions: [ClaudeSession], receivedAt: Date) {
        self.columns = columns
        self.sessions = sessions
        self.receivedAt = receivedAt
    }
}

// MARK: - Service

/// Source of Claude session state, plus the focus back-channel: asking the Mac
/// to bring a session's window up is a service concern (it outlives the widget
/// value and needs a network side effect).
public protocol ClaudeSessionsService: AnyObject {
    /// The latest reading, or nil when nothing has been pushed yet.
    func reading() -> ClaudeSessionsReading?
    /// Ask the Mac to raise Claude.app on this session. Fire-and-forget.
    func focus(sessionID: String)
}

public enum ClaudeSessionsServiceKeys {
    public static let sessions = ServiceKey<any ClaudeSessionsService>("claudeSessions")
}
