// ClaudeSessionFilter.swift — Which slice of the session board the rail's pills show.

import Foundation

/// One bucket of sessions, as the fullscreen rail's filter pills offer them.
///
/// The raw value is doing three jobs at once, on purpose: it is the pill's
/// LABEL, the token in the action string the rail sends
/// (`claude.filters.MT,/s`), and the case's name in a test. One string means the
/// rail can be told what to draw without `DashboardUI` learning anything about
/// Claude sessions — it is handed the labels and hands back whatever was lit.
///
/// The three buckets are exhaustive (`other` is defined as neither of the other
/// two), so lighting all three shows the same board as lighting none.
public enum ClaudeSessionFilter: String, CaseIterable, Sendable {
    /// Anything in the MemberTools family of repos.
    case memberTools = "MT"
    /// Sessions started by a slash command.
    case skills = "/s"
    /// Everything else.
    case other = "..."

    /// Separator between tokens in the wire string. Comma because no raw value
    /// contains one — `...` and `/s` both would collide with the obvious
    /// alternatives.
    static let separator = ","

    /// Whether this session belongs to the MemberTools family.
    ///
    /// `project` is the session directory's BASENAME — AgentManager derives it as
    /// `basename(originCwd ?? cwd)`, and `originCwd` is what makes a worktree
    /// session report its real repo rather than the throwaway worktree. So the
    /// values here are folder names: `MemberTools-Android`,
    /// `MemberTools-Android-MMA-5381`, `MemberTools-Mobile-Shared`, … A prefix
    /// match is what catches the sibling clones and the per-ticket worktrees
    /// without listing them, and new ones cost nothing.
    public static func isMemberTools(_ session: ClaudeSession) -> Bool {
        (session.project ?? "").lowercased().hasPrefix("membertools")
    }

    /// Whether this session was kicked off by a slash command — its title is the
    /// invocation, e.g. `/kickoff MMA-6006`.
    ///
    /// Matches the RAW `ClaudeSession.title`, never `Row.title`: that one has
    /// been truncated to the column width and may carry a `⚙N` agent-count
    /// suffix (see `ClaudeSessionsWidgetModel.rowTitle`).
    public static func isSkill(_ session: ClaudeSession) -> Bool {
        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.hasPrefix("/") && title.count > 1
    }

    /// Whether a session falls in this bucket.
    public func matches(_ session: ClaudeSession) -> Bool {
        switch self {
        case .memberTools: Self.isMemberTools(session)
        case .skills: Self.isSkill(session)
        case .other: !Self.isMemberTools(session) && !Self.isSkill(session)
        }
    }

    /// Whether `filters` lets this session through — the board shows the UNION of
    /// whatever is lit.
    ///
    /// **No pill lit means unfiltered**, and that rule lives here rather than at
    /// the call sites so the board can never be filtered down to nothing.
    public static func allows(_ session: ClaudeSession, _ filters: Set<Self>) -> Bool {
        filters.isEmpty || filters.contains { $0.matches(session) }
    }

    /// Reads a selection back out of an action string's suffix. Unknown tokens
    /// are dropped, and an empty string decodes to the empty set — the
    /// unfiltered state, which is exactly what "every pill tapped off" should
    /// mean.
    public static func decode(_ token: String) -> Set<Self> {
        Set(token.split(separator: Character(separator)).compactMap { Self(rawValue: String($0)) })
    }

    /// The wire form of a selection, in `allCases` order so the same set always
    /// produces the same string.
    public static func encode(_ filters: Set<Self>) -> String {
        allCases.filter(filters.contains).map(\.rawValue).joined(separator: separator)
    }
}
