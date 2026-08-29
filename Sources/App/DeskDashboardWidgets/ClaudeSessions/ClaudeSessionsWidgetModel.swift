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
    /// Most columns the tile will draw. A CEILING, not a shape: the board
    /// renders exactly as many columns as the daemon pushes, because those are
    /// user-configurable (`columns.js`) and adding one shouldn't need a Pi
    /// rebuild. Beyond this they'd be too narrow to read on the strip.
    public static let maxColumns = 5
    /// Most cards a column will render. Not a fitting constraint any more —
    /// the column scrolls — just a sane ceiling on how much a push can ask the
    /// tile to build.
    public static let slotCount = 12

    /// One display row, pre-formatted. `sessionID` is empty for blank slots.
    ///
    /// `flag` and `stage` are KINDS, not labels: the layout owns the words and
    /// the colours, this owns which one applies.
    public struct Row: Equatable, Sendable {
        public var title: String
        public var project: String
        public var model: String
        public var activity: String
        public var flag: String
        public var stage: String
        public var pullRequest: String
        public var changesRequested: Bool
        public var accentHex: String
        public var age: String
        public var sessionID: String

        static let blank = Row(
            title: "", project: "", model: "", activity: "", flag: "", stage: "",
            pullRequest: "", changesRequested: false, accentHex: "", age: "", sessionID: ""
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

    /// One header per column the daemon pushed — label, count, accent.
    private(set) var columns: [ColumnDisplay] = []
    /// One entry per column, holding up to `slotCount` rows. Variable length:
    /// the columns scroll, so blank slots would only add dead space to scroll
    /// through. (Blank padding was the fixed-height era's trick for keeping the
    /// node tree constant — see the layout's note on why that rule was about
    /// HOLD gestures, which these tap-only cards don't use.)
    private(set) var grid: [[Row]] = []
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
            columns = []
            grid = []
            countsLine = "Waiting for Mac…"
            isStale = false
            return
        }

        isStale = date.timeIntervalSince(reading.receivedAt) > staleAfter

        // The daemon's column set is user-configurable and open-ended; the tile
        // draws them all, in the daemon's order, up to what fits.
        let shown = Array(reading.columns.prefix(Self.maxColumns))

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
            let rows = sessions.prefix(Self.slotCount).map { session in
                Row(
                    title: Self.rowTitle(session, columns: shown.count),
                    project: session.project ?? "",
                    model: Self.modelLabel(session.model),
                    // Compact columns drop the activity line, like the web board.
                    activity: column.compact ? "" : Self.activityLabel(session, columns: shown.count),
                    flag: Self.flagKind(session),
                    stage: session.stage ?? "",
                    pullRequest: session.prNumber.map { "#\($0)" } ?? "",
                    changesRequested: session.prReviewDecision == "CHANGES_REQUESTED",
                    // Looked up from the board's OWN columns, so recolouring a
                    // column in config recolours these dots with it.
                    accentHex: Self.attentionColor(session, in: reading),
                    age: Self.ageLabel(session.ageSeconds),
                    sessionID: session.id
                )
            }
            cells.append(Array(rows))
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

    /// The colour for a card's dot: the accent of the column named by the
    /// session's `attention`, or nothing when the daemon didn't say (older
    /// daemon) — the layout then falls back to the card's own column.
    static func attentionColor(_ session: ClaudeSession, in reading: ClaudeSessionsReading) -> String {
        // What the daemon resolved, when it did — a stage-based board has no
        // attention column to look one up from.
        if let pushed = session.attentionColor, !pushed.isEmpty { return pushed }
        guard let attention = session.attention, !attention.isEmpty else { return "" }
        return reading.columns.first { $0.id == attention }?.colorHex ?? ""
    }

    /// The model chip's text, shortened the way the web board shortens it.
    static func modelLabel(_ model: String?) -> String {
        (model ?? "").replacingOccurrences(of: "claude-", with: "")
    }

    /// The activity line, truncated to the card like the title is.
    static func activityLabel(_ session: ClaudeSession, columns: Int = 3) -> String {
        guard let activity = session.lastActivity, !activity.isEmpty else { return "" }
        let limit = maxTitleLength(columns: columns) + 8
        if activity.count > limit {
            return String(activity.prefix(limit - 1)) + "…"
        }
        return activity
    }

    /// Why this card wants attention, as a KIND the layout renders.
    ///
    /// `blockedOn` is the daemon's real signal; `askPending` is the alias it
    /// still sends for Pis running an older build, so it is only consulted when
    /// `blockedOn` is absent. Being blocked outranks being stalled: "waiting on
    /// you" is actionable, "quiet for a while" is a guess.
    static func flagKind(_ session: ClaudeSession) -> String {
        if let blockedOn = session.blockedOn, !blockedOn.isEmpty { return blockedOn }
        if session.askPending { return "question" }
        if session.stalled { return "stalled" }
        return ""
    }

    /// Longest title a slot may carry, for a board of `columnCount` columns.
    /// GTK labels don't wrap or ellipsize here, so an unbounded title would
    /// widen its column and shove its neighbours — the model truncates instead.
    /// Calibrated from the measured three-column fit (34 glyphs): ~117 glyphs
    /// span the strip at caption size, less a few per column for the age
    /// readout sharing the line.
    static func maxTitleLength(columns: Int) -> Int {
        max(12, 117 / max(1, columns) - 5)
    }

    static func rowTitle(_ session: ClaudeSession, columns: Int = 3) -> String {
        var title = session.title
        let limit = maxTitleLength(columns: columns)
        if title.count > limit {
            title = String(title.prefix(limit - 1)) + "…"
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
