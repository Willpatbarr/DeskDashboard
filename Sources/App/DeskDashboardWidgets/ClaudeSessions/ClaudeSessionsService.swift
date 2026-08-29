// ClaudeSessionsService.swift — Claude Code sessions: reading types + service protocol.

import DashboardKit
import Foundation

// MARK: - Reading

/// One subagent a session spawned, as the daemon read it out of the parent's
/// transcript.
///
/// `running` and `seconds` arrive already computed. That is deliberate: the
/// daemon measures them against the Mac's clock, and the Pi's clock has no
/// reason to agree with it — a timestamp would have to be reconciled, a
/// duration doesn't.
public struct ClaudeSessionAgent: Equatable, Sendable {
    /// What the agent was asked to do — the `description` it was spawned with.
    public var label: String
    /// The subagent type (`Explore`, `general-purpose`, …), when it had one.
    public var agentType: String?
    /// Model override, when the spawn named one.
    public var model: String?
    /// Still in flight. A finished agent stays in the list — that history is
    /// the reason this exists separately from `agentCount`.
    public var running: Bool
    /// How long it has run, or how long it took. Nil when the transcript record
    /// carried no timestamp to measure from.
    public var seconds: Int?
    /// The agent returned an error.
    public var failed: Bool

    public init(
        label: String,
        agentType: String? = nil,
        model: String? = nil,
        running: Bool = false,
        seconds: Int? = nil,
        failed: Bool = false
    ) {
        self.label = label
        self.agentType = agentType
        self.model = model
        self.running = running
        self.seconds = seconds
        self.failed = failed
    }
}

/// One Claude Code session as the Mac's AgentManager daemon reports it.
public struct ClaudeSession: Equatable, Sendable {
    /// The desktop app's session id (`local_…`) — also the focus key.
    public var id: String
    public var title: String
    public var project: String?
    /// Model slug, e.g. `claude-opus-5`.
    public var model: String?
    /// The column this session would sit in if the PR column didn't exist —
    /// `working` | `needs-you` | `idle`. The card's dot is painted with THIS
    /// rather than its own column's colour, so a card parked in "PR Open"
    /// still shows whether it is running, waiting on you, or quiet.
    public var attention: String?
    /// The dot's colour, already resolved by the daemon. Sent rather than
    /// looked up because a stage-based board has no attention COLUMN to borrow
    /// a colour from; nil falls back to that lookup, then to the column accent.
    public var attentionColor: String?
    /// Where the work is: `planning` | `implementing` | `review` | `done`.
    /// The daemon derives it; nil when an older daemon is pushing.
    public var stage: String?
    /// Why the agent is stopped on a human: `question` | `plan` |
    /// `changes-requested`, else nil. Supersedes `askPending`, which the
    /// daemon still sends as an alias so an un-rebuilt Pi keeps working.
    public var blockedOn: String?
    /// The session's git branch, when it has one.
    public var branch: String?
    /// Pull request facts, when the session has one open.
    public var prNumber: Int?
    public var prState: String?
    /// GitHub's review verdict — `CHANGES_REQUESTED`, `APPROVED`, … Only this
    /// comes from `gh`; everything else above is local metadata.
    public var prReviewDecision: String?
    /// Column id assigned by the daemon's (user-configurable) column rules —
    /// e.g. `working` / `needs-you` / `idle`, but the set is open.
    public var column: String
    public var stalled: Bool
    public var askPending: Bool
    /// How many subagents are in flight RIGHT NOW — what the card's `⚙n`
    /// means. Not the length of `agents`, which also holds finished runs.
    public var agentCount: Int
    public var lastActivity: String?
    public var ageSeconds: Int

    // MARK: Detail-panel facts
    //
    // Everything below is shown only by the long-press detail panel. The card
    // has no room for any of it, but the daemon already knows all of it, so it
    // rides the same push rather than needing a second request when a panel
    // opens (the Pi cannot reach the Mac — see `PushClaudeSessionsService`).

    /// Recent subagents, newest first — running and finished alike.
    public var agents: [ClaudeSessionAgent]
    /// `owner/name` of the GitHub repo, when the session has a PR.
    public var repo: String?
    /// The branch this session's work merges INTO.
    public var base: String?
    /// The session is running in a git worktree rather than the repo itself.
    public var worktree: Bool
    public var prIsDraft: Bool
    /// Reasoning effort, when the session set one.
    public var effort: String?
    /// `default` | `plan` | `acceptEdits` | `bypassPermissions`.
    public var permissionMode: String?
    /// The plan document the session was started from, without its extension.
    public var planName: String?

    public init(
        id: String,
        title: String,
        project: String? = nil,
        model: String? = nil,
        attention: String? = nil,
        attentionColor: String? = nil,
        stage: String? = nil,
        blockedOn: String? = nil,
        branch: String? = nil,
        prNumber: Int? = nil,
        prState: String? = nil,
        prReviewDecision: String? = nil,
        column: String,
        stalled: Bool = false,
        askPending: Bool = false,
        agentCount: Int = 0,
        lastActivity: String? = nil,
        ageSeconds: Int = 0,
        // Defaulted so every existing initialiser — the tests, the simulated
        // service, the ingest map — keeps compiling untouched.
        agents: [ClaudeSessionAgent] = [],
        repo: String? = nil,
        base: String? = nil,
        worktree: Bool = false,
        prIsDraft: Bool = false,
        effort: String? = nil,
        permissionMode: String? = nil,
        planName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.project = project
        self.model = model
        self.attention = attention
        self.attentionColor = attentionColor
        self.stage = stage
        self.blockedOn = blockedOn
        self.branch = branch
        self.prNumber = prNumber
        self.prState = prState
        self.prReviewDecision = prReviewDecision
        self.column = column
        self.stalled = stalled
        self.askPending = askPending
        self.agentCount = agentCount
        self.lastActivity = lastActivity
        self.ageSeconds = ageSeconds
        self.agents = agents
        self.repo = repo
        self.base = base
        self.worktree = worktree
        self.prIsDraft = prIsDraft
        self.effort = effort
        self.permissionMode = permissionMode
        self.planName = planName
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
