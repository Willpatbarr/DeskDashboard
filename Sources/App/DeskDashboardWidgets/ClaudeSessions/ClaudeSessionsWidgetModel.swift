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
    public static let slotCount = 5

    /// One display row, pre-formatted. `sessionID` is empty for blank slots.
    public struct Row: Equatable, Sendable {
        public var title: String
        public var age: String
        public var sessionID: String

        static let blank = Row(title: "", age: "", sessionID: "")
    }

    private let service: any ClaudeSessionsService
    /// Reading older than this is flagged STALE — the Mac daemon pushes every
    /// few seconds, so a quiet minute means the producer is gone.
    private let staleAfter: TimeInterval

    /// `columnCount` header strings — "Working (2)" — blanks for absent columns.
    private(set) var columnHeaders: [String] = Array(repeating: "", count: columnCount)
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
            columnHeaders = Array(repeating: "", count: Self.columnCount)
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

        var headers: [String] = []
        var columns: [[Row]] = []
        for column in shown {
            let sessions = reading.sessions.filter { $0.column == column.id }
            headers.append("\(column.label) (\(sessions.count))")
            var rows = sessions.prefix(Self.slotCount).map { session in
                Row(
                    title: Self.rowTitle(session),
                    age: Self.ageLabel(session.ageSeconds),
                    sessionID: session.id
                )
            }
            while rows.count < Self.slotCount {
                rows.append(.blank)
            }
            columns.append(Array(rows))
        }
        while headers.count < Self.columnCount {
            headers.append("")
            columns.append(Array(repeating: .blank, count: Self.slotCount))
        }
        columnHeaders = headers
        grid = columns

        var counts: [String] = []
        for column in reading.columns {
            let n = reading.sessions.filter { $0.column == column.id }.count
            counts.append("\(n) \(column.label.lowercased())")
        }
        countsLine = counts.isEmpty ? "No sessions" : counts.joined(separator: " · ")
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
