// ClaudeBoard.swift — Board spec: the Claude session board, clock alongside.

import DashboardKit
import DashboardUI
import DeskDashboardWidgets

extension BoardColumns {
    /// The Claude Code session board: one widget, the whole strip. Time lives in
    /// the fullscreen rail's mini clock, so no clock column here. The session
    /// tile draws its own title line, so the chrome title is hidden.
    public static let claude: [BoardColumn] = [
        // Containerless + flush: the kanban draws its own wells and cards, so
        // the tile contributes no surface and no inner padding — the columns
        // reach the tile bounds.
        BoardColumn("claude", .claudeSessions, 1, containerless: true, flush: true, hidesTitle: true),
    ]
}
