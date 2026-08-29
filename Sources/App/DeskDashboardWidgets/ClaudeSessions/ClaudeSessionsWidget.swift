// ClaudeSessionsWidget.swift — Claude sessions DISPLAY layer: the session board, rows tappable to focus.

import DashboardKit
import Foundation

/// The Claude Code session kanban. Each slot is one session; tapping a slot
/// asks the Mac's AgentManager daemon to raise Claude.app on that session.
///
/// The grid travels to the layout through `metadata`: one entry per slot in
/// column-major order (`columnCount × slotCount` entries, blanks included so
/// the count is constant), the visible line in `label` and `age⟨US⟩sessionID`
/// packed into `value`. Column headers ride in `secondaryText`, ⟨US⟩-joined.
/// (`WidgetContent` has no grid type — the metadata pairs are the one
/// structured channel a layout can read.)
public struct ClaudeSessionsWidget: ServiceBackedWidget, InteractiveWidget {
    /// Action-name vocabulary shared with `ClaudeSessionsLayout`.
    public enum Action {
        /// Prefix; the tapped session id follows.
        public static let focusPrefix = "claude.focus."
        /// Raised by blank filler rows. Inert.
        public static let none = "claude.none"
    }

    /// Separates the packed fields inside a metadata value and the header
    /// fields inside `secondaryText` (U+001F, the unit separator — never
    /// appears in any field).
    public static let fieldSeparator = "\u{1F}"
    /// Separates one column's header fields from the next inside
    /// `secondaryText` (U+001E, the record separator).
    public static let columnSeparator = "\u{1E}"

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
        let blankColumn = [ClaudeSessionsWidgetModel.Row](
            repeating: .blank,
            count: ClaudeSessionsWidgetModel.slotCount
        )
        let grid = model?.grid
            ?? Array(repeating: blankColumn, count: ClaudeSessionsWidgetModel.columnCount)
        let columns = model?.columns
            ?? Array(repeating: .blank, count: ClaudeSessionsWidgetModel.columnCount)

        // Header record per column: label ⟨US⟩ count ⟨US⟩ colorHex, columns
        // joined by ⟨RS⟩. Blank columns carry empty strings so the layout's
        // node count never changes.
        let headers = columns.map { column in
            [
                column.label,
                column.label.isEmpty ? "" : "\(column.count)",
                column.colorHex,
            ].joined(separator: Self.fieldSeparator)
        }.joined(separator: Self.columnSeparator)

        return WidgetContent(
            title: configuration.title,
            primaryText: model?.countsLine ?? "Waiting for Mac…",
            secondaryText: headers,
            accessoryText: (model?.isStale ?? false) ? "STALE" : nil,
            metadata: grid.flatMap { column in
                column.map { row in
                    WidgetContentMetadata(
                        label: row.title,
                        value: [
                            row.age, row.sessionID, row.project,
                            row.model, row.activity, row.flag,
                        ].joined(separator: Self.fieldSeparator)
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
