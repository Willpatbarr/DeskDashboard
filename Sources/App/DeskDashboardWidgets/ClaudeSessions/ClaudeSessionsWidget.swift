// ClaudeSessionsWidget.swift — Claude sessions DISPLAY layer: the session board, rows tappable to focus.

import DashboardKit
import Foundation

/// The Claude Code session kanban. Each slot is one session; tapping a slot
/// asks the Mac's AgentManager daemon to raise Claude.app on that session.
///
/// The grid travels to the layout through `metadata` — one entry per card, in
/// column order — with the column headers in `secondaryText`. `WidgetContent`
/// has no grid type, so the metadata pairs are the one structured channel a
/// layout can read; `ClaudeCardPacking` owns what goes where.
public struct ClaudeSessionsWidget: ServiceBackedWidget, InteractiveWidget {
    /// Action-name vocabulary shared with `ClaudeSessionsLayout`.
    public enum Action {
        /// Prefix; the tapped session id follows.
        public static let focusPrefix = "claude.focus."
        /// Prefix; the rail's WHOLE lit selection follows, comma-separated (see
        /// `ClaudeSessionFilter.encode`). Sent as a full set rather than a toggle
        /// so the rail's pills and this widget's filters cannot disagree — and an
        /// empty suffix is a legitimate value meaning "nothing lit".
        public static let filtersPrefix = "claude.filters."
        /// Prefix; the held session's id follows. Raised by a LONG PRESS on a
        /// card — a tap still focuses the session on the Mac.
        public static let detailPrefix = "claude.detail."
        /// Dismisses the detail panel. Deliberately shares `detailPrefix`, so
        /// the handler below must test for it first — a session can never be
        /// called `close` because ids are `local_…`.
        public static let closeDetail = "claude.detail.close"
        /// Raised by blank filler rows. Inert.
        public static let none = "claude.none"
    }


    public var configuration: WidgetConfiguration
    public var boundService: (any ClaudeSessionsService)?
    public var model: ClaudeSessionsWidgetModel?

    public init(
        configuration: WidgetConfiguration = WidgetConfiguration(
            title: "Claude",
            size: .large,
            refreshRate: .seconds(1)
        )
    ) {
        self.configuration = configuration
    }

    // MARK: - Service-backed lifecycle

    public var serviceKey: ServiceKey<any ClaudeSessionsService> { ClaudeSessionsServiceKeys.sessions }

    public func makeModel(_ service: any ClaudeSessionsService) -> ClaudeSessionsWidgetModel {
        ClaudeSessionsWidgetModel(service: service)
    }

    public func makeFallbackService() -> any ClaudeSessionsService {
        SimulatedClaudeSessionsService()
    }

    // MARK: - Rendering

    public func render(environment: DashboardEnvironment) -> WidgetContent {
        let grid = model?.grid ?? []
        let columns = model?.columns ?? []

        // Field ORDER for both of these lives in `ClaudeCardPacking`, which the
        // layout reads back through — see there for why it isn't spelled out
        // in two places.
        let headers = columns.enumerated().map { index, column in
            ClaudeColumnField.pack([
                .label: column.label,
                .count: column.label.isEmpty ? "" : "\(column.count)",
                .colorHex: column.colorHex,
                .rendered: "\(index < grid.count ? grid[index].count : 0)",
            ])
        }.joined(separator: ClaudeColumnField.columnSeparator)

        let cards = grid.flatMap { column in
            column.map { row in
                WidgetContentMetadata(
                    label: row.title,
                    value: ClaudeCardField.pack([
                        .age: row.age,
                        .sessionID: row.sessionID,
                        .project: row.project,
                        .model: row.model,
                        .activity: row.activity,
                        .flag: row.flag,
                        .stage: row.stage,
                        .pullRequest: row.pullRequest,
                        .changesRequested: row.changesRequested ? "1" : "",
                        .accentHex: row.accentHex,
                    ])
                )
            }
        }

        return WidgetContent(
            title: configuration.title,
            primaryText: model?.countsLine ?? "Waiting for Mac…",
            secondaryText: headers,
            accessoryText: (model?.isStale ?? false) ? "STALE" : nil,
            // Cards first, then the open session's detail block, then one entry
            // per subagent. No sentinel is needed to tell them apart: the layout
            // already sums every column's `rendered` to walk the cards, so
            // anything at or past that index is the panel — and when nothing is
            // open there is nothing past it.
            metadata: cards + detailMetadata()
        )
    }

    /// The open session's panel as metadata entries — the packed detail block,
    /// followed by one entry per subagent. Empty when no panel is open, which is
    /// what tells the layout not to build the overlay at all.
    private func detailMetadata() -> [WidgetContentMetadata] {
        guard let detail = model?.detail else { return [] }
        let block = WidgetContentMetadata(
            label: detail.title,
            value: ClaudeDetailField.pack([
                .sessionID: detail.sessionID,
                .title: detail.title,
                .activity: detail.activity,
                .project: detail.project,
                .repo: detail.repo,
                .branch: detail.branch,
                .base: detail.base,
                .worktree: detail.worktree ? "1" : "",
                .stage: detail.stage,
                .flag: detail.flag,
                .pullRequest: detail.pullRequest,
                .prState: detail.prState,
                .prReviewDecision: detail.prReviewDecision,
                .prIsDraft: detail.prIsDraft ? "1" : "",
                .model: detail.model,
                .effort: detail.effort,
                .permissionMode: detail.permissionMode,
                .planName: detail.planName,
                .age: detail.age,
                .accentHex: detail.accentHex,
                .columnLabel: detail.columnLabel,
                .columnColorHex: detail.columnColorHex,
            ])
        )
        return [block] + detail.agents.map { agent in
            WidgetContentMetadata(
                label: agent.label,
                value: ClaudeAgentField.pack([
                    .label: agent.label,
                    .agentType: agent.agentType ?? "",
                    .model: agent.model ?? "",
                    .running: agent.running ? "1" : "",
                    .seconds: agent.seconds.map(String.init) ?? "",
                    .failed: agent.failed ? "1" : "",
                ])
            )
        }
    }

    // MARK: - Taps

    public func handle(action: String, environment: DashboardEnvironment) {
        // Before the focus guard, and deliberately without an emptiness check:
        // `claude.filters.` with nothing after it is how the rail says every pill
        // is dark, which decodes to the empty set — the unfiltered board.
        if action.hasPrefix(Action.filtersPrefix) {
            let token = String(action.dropFirst(Action.filtersPrefix.count))
            model?.setFilters(ClaudeSessionFilter.decode(token))
            return
        }
        // Close before open: `closeDetail` starts with `detailPrefix`, so the
        // order here is what keeps "close" from being read as a session id.
        if action == Action.closeDetail {
            model?.setOpenSession(nil)
            return
        }
        if action.hasPrefix(Action.detailPrefix) {
            let sessionID = String(action.dropFirst(Action.detailPrefix.count))
            guard !sessionID.isEmpty else { return }
            model?.setOpenSession(sessionID)
            return
        }
        guard action.hasPrefix(Action.focusPrefix) else { return }
        let sessionID = String(action.dropFirst(Action.focusPrefix.count))
        guard !sessionID.isEmpty else { return }
        // Through the service, not the widget value — and a session that
        // vanished since the snapshot just 404s on the Mac.
        (boundService ?? model?.sessionsService)?.focus(sessionID: sessionID)
    }
}
