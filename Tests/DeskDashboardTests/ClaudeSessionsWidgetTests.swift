// ClaudeSessionsWidgetTests.swift — The session board: rows, taps, and GTK structural stability.

import Foundation
import Testing
@testable import DashboardKit
@testable import DeskDashboardWidgets

// MARK: - Test doubles

private final class FixedClaudeSessionsService: ClaudeSessionsService {
    var stored: ClaudeSessionsReading?
    var focused: [String] = []

    init(_ reading: ClaudeSessionsReading?) {
        stored = reading
    }

    func reading() -> ClaudeSessionsReading? { stored }
    func focus(sessionID: String) { focused.append(sessionID) }
}

private func reading(_ sessions: [ClaudeSession]) -> ClaudeSessionsReading {
    ClaudeSessionsReading(
        columns: [
            ClaudeSessionColumn(id: "working", label: "Working"),
            ClaudeSessionColumn(id: "needs-you", label: "Needs You"),
            ClaudeSessionColumn(id: "idle", label: "Idle"),
        ],
        sessions: sessions,
        receivedAt: Date()
    )
}

// MARK: - Model

@Test func modelPadsTheGridToAFixedShape() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
        ClaudeSession(id: "local_b", title: "Two", column: "idle", ageSeconds: 9),
    ]))
    let model = ClaudeSessionsWidgetModel(service: service)
    model.refresh(at: Date())

    #expect(model.grid.count == ClaudeSessionsWidgetModel.columnCount)
    #expect(model.grid.allSatisfy { $0.count == ClaudeSessionsWidgetModel.slotCount })
    #expect(model.grid[0][0].sessionID == "local_a")   // working column
    #expect(model.grid[0][1] == .blank)
    #expect(model.grid[2][0].sessionID == "local_b")   // idle column
}

@Test func modelHeadersCarryPerColumnCounts() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "a", title: "A", column: "working", ageSeconds: 1),
        ClaudeSession(id: "b", title: "B", column: "idle", ageSeconds: 1),
        ClaudeSession(id: "c", title: "C", column: "idle", ageSeconds: 1),
    ]))
    let model = ClaudeSessionsWidgetModel(service: service)
    model.refresh(at: Date())

    #expect(model.columns.map(\.label) == ["Working", "Needs You", "Idle"])
    #expect(model.columns.map(\.count) == [1, 0, 2])
    // Colors fall back to the web defaults when the push omits them.
    #expect(model.columns[0].colorHex == "#4ade80")
    #expect(model.countsLine == "1 working · 0 needs you · 2 idle")
}

@Test func longTitlesAreTruncatedForTheColumn() {
    let long = String(repeating: "x", count: 60)
    let session = ClaudeSession(id: "a", title: long, column: "working", agentCount: 2)

    let title = ClaudeSessionsWidgetModel.rowTitle(session)
    #expect(title.hasSuffix("… ⚙2"))
    #expect(title.count <= ClaudeSessionsWidgetModel.maxTitleLength + 3)
}

@Test func aQuietProducerFlagsTheBoardStale() {
    var old = reading([])
    old.receivedAt = Date(timeIntervalSinceNow: -120)
    let service = FixedClaudeSessionsService(old)
    let model = ClaudeSessionsWidgetModel(service: service)
    model.refresh(at: Date())

    #expect(model.isStale)
}

// MARK: - Taps

@Test func tappingARowFocusesThatSessionThroughTheService() {
    let service = FixedClaudeSessionsService(reading([]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))

    dashboard.perform(action: "claude.focus.local_abc", on: id)
    dashboard.perform(action: "claude.none", on: id)
    dashboard.perform(action: "claude.focus.", on: id)

    #expect(service.focused == ["local_abc"])
}

// MARK: - Focus queue (the firewalled-Mac path)

@Test func withNoMacURLTapsQueueUntilDrainedOnce() {
    let store = PushClaudeSessionsService() // no agentManagerBaseURL
    store.focus(sessionID: "local_a")
    store.focus(sessionID: "local_b")

    #expect(store.drainPendingFocus() == ["local_a", "local_b"])
    #expect(store.drainPendingFocus().isEmpty)
}

// MARK: - Layout structural stability (the GTK rule — see LifeCounterLayout)

@Test func theSessionTileHasTheSameNodesEmptyOrFull() {
    let service = FixedClaudeSessionsService(nil)
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))

    let bare = WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))

    service.stored = reading([
        ClaudeSession(
            id: "local_a", title: "Busy one", project: "Repo", column: "working",
            agentCount: 3, lastActivity: "Building", ageSeconds: 42
        ),
        ClaudeSession(id: "local_b", title: "Waiting one", column: "needs-you", ageSeconds: 900),
        ClaudeSession(id: "local_c", title: "Cold one", column: "idle", ageSeconds: 9000),
    ])
    dashboard.tick(at: Date(timeIntervalSinceNow: 2))
    let full = WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))

    #expect(shape(of: bare) == shape(of: full))
}

private func snapshotContent(_ dashboard: Dashboard, _ id: WidgetID) -> WidgetContent {
    dashboard.attachedWidgetSnapshots.first { $0.id == id }?.content ?? WidgetContent(primaryText: "")
}

/// The node tree with every string blanked — structure only. Tap ACTIONS are
/// deliberately excluded (unlike InteractiveWidgetTests' shape): each session
/// row's action carries its session id, which is exactly the part allowed to
/// change while the tree shape must not.
private func shape(of node: WidgetView) -> String {
    switch node {
    case .text: "text"
    case .badge: "badge"
    case .spacer: "spacer"
    case .divider: "divider"
    case .fittedText: "fitted"
    case .progressBar: "progress"
    case .playState: "playState"
    case let .tappable(_, hold, child):
        "tappable(\(hold ?? "-"))[\(shape(of: child))]"
    case let .centered(children):
        "centered[\(children.map(shape(of:)).joined(separator: ","))]"
    case let .stack(axis, _, children):
        "stack(\(axis))[\(children.map(shape(of:)).joined(separator: ","))]"
    case let .region(minWidth, minHeight, child):
        "region(\(minWidth),\(minHeight))[\(shape(of: child))]"
    case .coloredText:
        "ctext"
    case let .columns(_, children):
        "columns[\(children.map(shape(of:)).joined(separator: ","))]"
    case let .card(_, _, cornerRadius, padding, child):
        "card(\(cornerRadius),\(padding))[\(shape(of: child))]"
    }
}
