// SimulatedClaudeSessionsService.swift — Claude sessions source (dev): a plausible fake board.

import DashboardKit
import Foundation

/// Simulated source so the tile renders without the Mac daemon: a small fake
/// board whose ages tick forward from launch. Focus taps just log.
///
/// The fixtures deliberately fill all three of `ClaudeSessionFilter`'s buckets —
/// a MemberTools clone, a worktree of one, a slash-command session and a plain
/// one — because a Mac run with no daemon is where the rail's filter pills get
/// eyeballed, and pills that all show the same board look broken.
public final class SimulatedClaudeSessionsService: ClaudeSessionsService, @unchecked Sendable {
    private let startedAt = Date()

    public init() {}

    public func reading() -> ClaudeSessionsReading? {
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        return ClaudeSessionsReading(
            columns: [
                ClaudeSessionColumn(id: "working", label: "Working", colorHex: "#4ade80"),
                ClaudeSessionColumn(id: "needs-you", label: "Needs You", colorHex: "#fbbf24"),
                ClaudeSessionColumn(id: "idle", label: "Idle", colorHex: "#6b7280", compact: true),
            ],
            sessions: [
                ClaudeSession(
                    id: "sim-1", title: "MMA-1234 directory refactor",
                    project: "MemberTools-Android",
                    model: "claude-opus-5", stage: "implementing", branch: "MMA-1234",
                    column: "working", agentCount: 2,
                    lastActivity: "Running gradle build", ageSeconds: 8 + elapsed,
                    // Two in flight (matching `agentCount`) and two already
                    // done, including a failure — the detail panel's three
                    // states, so all of them are visible on a Mac dev run.
                    agents: [
                        ClaudeSessionAgent(label: "Map the directory module", agentType: "Explore",
                                           running: true, seconds: 12 + elapsed),
                        ClaudeSessionAgent(label: "Sweep the test fixtures",
                                           agentType: "general-purpose",
                                           running: true, seconds: 4 + elapsed),
                        ClaudeSessionAgent(label: "Rewrite the adapter", agentType: "general-purpose",
                                           model: "claude-opus-5", running: false, seconds: 214),
                        ClaudeSessionAgent(label: "Regenerate the wiki cards", agentType: "Explore",
                                           running: false, seconds: 61, failed: true),
                    ],
                    repo: "org/MemberTools-Android", base: "develop", worktree: true,
                    effort: "high", permissionMode: "acceptEdits",
                    planName: "MMA-1234-directory-refactor"
                ),
                // A worktree session: the daemon resolves `originCwd`, so its
                // project is the real repo's folder rather than the worktree's.
                ClaudeSession(
                    id: "sim-2", title: "Calendar zoom polish",
                    project: "MemberTools-Mobile-Shared",
                    model: "claude-fable-5", stage: "planning", blockedOn: "plan",
                    column: "needs-you", askPending: false,
                    lastActivity: "Plan awaiting approval", ageSeconds: 260 + elapsed
                ),
                // The case the whole reshape exists for: a PR the reviewer sent
                // back, which no local metadata knows about.
                ClaudeSession(
                    id: "sim-3", title: "Directory list UX",
                    project: "MemberTools-Android-MMA-5466",
                    model: "claude-opus-5", stage: "review", blockedOn: "changes-requested",
                    branch: "MMA-5466", prNumber: 2070, prState: "OPEN",
                    prReviewDecision: "CHANGES_REQUESTED", column: "needs-you",
                    lastActivity: "PR #2070 changes requested", ageSeconds: 900 + elapsed,
                    repo: "org/MemberTools-Android", base: "develop",
                    effort: "medium", permissionMode: "default"
                ),
                // Slash-command session — its title IS the invocation, which is
                // the whole of what the `/s` bucket matches on.
                ClaudeSession(
                    id: "sim-5", title: "/kickoff MMA-6006",
                    project: "MemberTools-Android",
                    model: "claude-opus-5", stage: "planning",
                    column: "working", lastActivity: "Drafting requirements",
                    ageSeconds: 95 + elapsed
                ),
                ClaudeSession(
                    id: "sim-4", title: "XML wiki sync", project: "XMLWiki",
                    model: "claude-opus-5", stage: "done", prNumber: 2044,
                    prState: "MERGED", column: "idle", lastActivity: "Done",
                    ageSeconds: 7500 + elapsed
                ),
            ],
            receivedAt: Date()
        )
    }

    public func focus(sessionID: String) {
        print("[claude-sessions] (simulated) focus \(sessionID)")
    }
}
