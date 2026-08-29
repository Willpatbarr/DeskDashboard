// ClaudeSessionsWidgetModel.swift — Claude sessions TRANSFORM layer: kanban grid, headers, staleness.

import DashboardKit
import Foundation

/// Transform layer: turns the service's reading into exactly what the tile
/// draws — a kanban grid of FIXED shape (columns × slots, blanks as empty
/// strings), per-column headers with counts, and a staleness flag.
///
/// The grid shape is fixed because the GTK backend requires a structurally
/// constant node tree — see LifeCounterLayout's note; a board that grew a row
/// mid-press would cancel the in-flight gesture.
public final class ClaudeSessionsWidgetModel: WidgetModel {
    /// Kanban shape. Also the layout's contract: the model pads/truncates to
    /// exactly `columnCount` columns of `slotCount` rows each.
    public static let columnCount = 3
    /// Three, not five: a web-style card is three text lines tall, and five of
    /// them outgrew the strip's tile height (the web board scrolls; the panel
    /// cannot).
    public static let slotCount = 3

    /// One display row, pre-formatted. `sessionID` is empty for blank slots.
    public struct Row: Equatable, Sendable {
        public var title: String
        public var project: String
        public var model: String
        public var activity: String
        public var flag: String
        public var age: String
        public var sessionID: String

        static let blank = Row(
            title: "", project: "", model: "", activity: "", flag: "", age: "", sessionID: ""
        )
    }

    /// One column's header line, mirroring the web board: label, count, accent.
    public struct ColumnDisplay: Equatable, Sendable {
        public var label: String
        public var count: Int
        public var colorHex: String
        public var compact: Bool

        static let blank = ColumnDisplay(label: "", count: 0, colorHex: "", compact: false)
    }

    /// Accents when the daemon's push omits them — the web board's defaults.
    static let fallbackColors = ["#4ade80", "#fbbf24", "#6b7280"]

    private let service: any ClaudeSessionsService
    /// Reading older than this is flagged STALE — the Mac daemon pushes every
    /// few seconds, so a quiet minute means the producer is gone.
    private let staleAfter: TimeInterval

    /// `columnCount` column headers — label, count, accent — blanks for absent
    /// columns.
    private(set) var columns: [ColumnDisplay] = Array(repeating: .blank, count: columnCount)
    /// `columnCount` columns of exactly `slotCount` rows.
    private(set) var grid: [[Row]] = Array(
        repeating: Array(repeating: .blank, count: slotCount),
        count: columnCount
    )
    private(set) var countsLine: String = "Waiting for Mac…"
    private(set) var isStale = false

    public init(service: any ClaudeSessionsService, staleAfter: TimeInterval = 60) {
        self.service = service
        self.staleAfter = staleAfter
    }

    /// The service, for the widget's tap handler — focus must go through the
    /// service object, not the widget value.
    var sessionsService: any ClaudeSessionsService { service }

    public func activate() {
        refresh(at: Date())
    }

    public func tick(_ tick: DashboardTick, environment: DashboardEnvironment) {
        refresh(at: tick.date)
    }

    public func update(environment: DashboardEnvironment) {
        refresh(at: Date())
    }

    func refresh(at date: Date) {
        guard let reading = service.reading() else {
            columns = Array(repeating: .blank, count: Self.columnCount)
            grid = Array(
                repeating: Array(repeating: .blank, count: Self.slotCount),
                count: Self.columnCount
            )
            countsLine = "Waiting for Mac…"
            isStale = false
            return
        }

        isStale = date.timeIntervalSince(reading.receivedAt) > staleAfter

        // The daemon's column set is user-configurable and open-ended; the tile
        // shows the first `columnCount` of them, in the daemon's order.
        let shown = Array(reading.columns.prefix(Self.columnCount))

        var displays: [ColumnDisplay] = []
        var cells: [[Row]] = []
        for (index, column) in shown.enumerated() {
            let sessions = reading.sessions.filter { $0.column == column.id }
            displays.append(ColumnDisplay(
                label: column.label,
                count: sessions.count,
                colorHex: column.colorHex
                    ?? Self.fallbackColors[index % Self.fallbackColors.count],
                compact: column.compact
            ))
            var rows = sessions.prefix(Self.slotCount).map { session in
                Row(
                    title: Self.rowTitle(session),
                    project: session.project ?? "",
                    model: Self.modelLabel(session.model),
                    // Compact columns drop the activity line, like the web board.
                    activity: column.compact ? "" : Self.activityLabel(session),
                    flag: Self.flagLabel(session),
                    age: Self.ageLabel(session.ageSeconds),
                    sessionID: session.id
                )
            }
            while rows.count < Self.slotCount {
                rows.append(.blank)
            }
            cells.append(Array(rows))
        }
        while displays.count < Self.columnCount {
            displays.append(.blank)
            cells.append(Array(repeating: .blank, count: Self.slotCount))
        }
        columns = displays
        grid = cells

        var counts: [String] = []
        for column in reading.columns {
            let n = reading.sessions.filter { $0.column == column.id }.count
            counts.append("\(n) \(column.label.lowercased())")
        }
        countsLine = counts.isEmpty ? "No sessions" : counts.joined(separator: " · ")
    }

    /// The model chip's text, shortened the way the web board shortens it.
    static func modelLabel(_ model: String?) -> String {
        (model ?? "").replacingOccurrences(of: "claude-", with: "")
    }

    /// The activity line, truncated to the card like the title is.
    static func activityLabel(_ session: ClaudeSession) -> String {
        guard let activity = session.lastActivity, !activity.isEmpty else { return "" }
        if activity.count > maxTitleLength + 8 {
            return String(activity.prefix(maxTitleLength + 7)) + "…"
        }
        return activity
    }

    /// The card's warning flag — the web board's wording.
    static func flagLabel(_ session: ClaudeSession) -> String {
        if session.askPending { return "question waiting" }
        if session.stalled { return "stalled?" }
        return ""
    }

    /// Longest title a slot may carry. GTK labels don't wrap or ellipsize here,
    /// so an unbounded title would widen its whole column past its third of the
    /// tile — the model truncates instead, sized to a kanban column at the
    /// panel's secondary type (~34 glyphs fits with the age readout beside it).
    static let maxTitleLength = 34

    static func rowTitle(_ session: ClaudeSession) -> String {
        var title = session.title
        if title.count > maxTitleLength {
            title = String(title.prefix(maxTitleLength - 1)) + "…"
        }
        if session.agentCount > 0 {
            title += " ⚙\(session.agentCount)"
        }
        return title
    }

    static func ageLabel(_ seconds: Int) -> String {
        switch seconds {
        case ..<60: "\(seconds)s"
        case ..<3600: "\(seconds / 60)m"
        default: "\(seconds / 3600)h \(seconds % 3600 / 60)m"
        }
    }
}
