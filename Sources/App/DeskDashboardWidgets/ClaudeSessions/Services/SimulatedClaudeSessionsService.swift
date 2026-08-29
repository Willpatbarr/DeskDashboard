// SimulatedClaudeSessionsService.swift — Claude sessions source (dev): a plausible fake board.

import DashboardKit
import Foundation

/// Simulated source so the tile renders without the Mac daemon: a small fake
/// board whose ages tick forward from launch. Focus taps just log.
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
                    id: "sim-1", title: "MMA-1234 directory refactor", project: "MemberTools",
                    model: "claude-opus-5", column: "working", agentCount: 2,
                    lastActivity: "Running gradle build", ageSeconds: 8 + elapsed
                ),
                ClaudeSession(
                    id: "sim-2", title: "Calendar zoom polish", project: "MemberTools",
                    model: "claude-fable-5", column: "needs-you", askPending: true,
                    lastActivity: "Question waiting", ageSeconds: 260 + elapsed
                ),
                ClaudeSession(
                    id: "sim-3", title: "XML wiki sync", project: "XMLWiki",
                    model: "claude-opus-5", column: "idle", lastActivity: "Done",
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
