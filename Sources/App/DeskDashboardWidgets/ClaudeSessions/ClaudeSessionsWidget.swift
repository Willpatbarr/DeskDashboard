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

        return WidgetContent(
            title: configuration.title,
            primaryText: model?.countsLine ?? "Waiting for Mac…",
            secondaryText: headers,
            accessoryText: (model?.isStale ?? false) ? "STALE" : nil,
            metadata: grid.flatMap { column in
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
        )
    }

    // MARK: - Taps

    public func handle(action: String, environment: DashboardEnvironment) {
        guard action.hasPrefix(Action.focusPrefix) else { return }
        let sessionID = String(action.dropFirst(Action.focusPrefix.count))
        guard !sessionID.isEmpty else { return }
        // Through the service, not the widget value — and a session that
        // vanished since the snapshot just 404s on the Mac.
        (boundService ?? model?.sessionsService)?.focus(sessionID: sessionID)
    }
}
