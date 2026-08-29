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

@Test func modelGroupsSessionsIntoColumnsWithoutPadding() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
        ClaudeSession(id: "local_b", title: "Two", column: "idle", ageSeconds: 9),
    ]))
    let model = ClaudeSessionsWidgetModel(service: service)
    model.refresh(at: Date())

    // Always `columnCount` columns, but each holds only its real sessions —
    // the columns scroll, so blank padding would just be dead scroll space.
    #expect(model.grid.count == ClaudeSessionsWidgetModel.columnCount)
    #expect(model.grid.map(\.count) == [1, 0, 1])
    #expect(model.grid[0][0].sessionID == "local_a")   // working column
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

// MARK: - Layout

@Test func everyCardIsTapOnlySoAReRenderCannotStrandAHold() {
    // This tile has VARIABLE node counts (columns scroll, so cards are not
    // padded to a fixed shape). `lifeCounter`'s fixed-shape rule exists because
    // a node inserted mid-press makes GTK cancel a HOLD's gesture, so its
    // auto-repeat never receives a release and runs away. That cannot happen
    // while every region here is tap-only — which is what this pins.
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
        ClaudeSession(id: "local_b", title: "Two", column: "needs-you", ageSeconds: 40),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date(timeIntervalSinceNow: 2))

    var holds: [String?] = []
    collectHolds(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id)), into: &holds)

    #expect(!holds.isEmpty)
    #expect(holds.allSatisfy { $0 == nil })
}

@Test func columnsGrowWithTheirOwnSessions() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date(timeIntervalSinceNow: 2))
    let oneCard = tapActions(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id)))

    service.stored = reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
        ClaudeSession(id: "local_b", title: "Two", column: "working", ageSeconds: 6),
        ClaudeSession(id: "local_c", title: "Three", column: "idle", ageSeconds: 7),
    ])
    dashboard.tick(at: Date(timeIntervalSinceNow: 4))
    let threeCards = tapActions(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id)))

    // Each card's action carries its own session, and the walk finds every
    // column's slice of the flat metadata list (`local_c` is in column three).
    #expect(oneCard == ["claude.focus.local_a"])
    #expect(threeCards == [
        "claude.focus.local_a", "claude.focus.local_b", "claude.focus.local_c",
    ])
}

private func tapActions(_ node: WidgetView) -> [String] {
    switch node {
    case let .tappable(action, _, child):
        [action] + tapActions(child)
    case let .stack(_, _, children):
        children.flatMap(tapActions)
    case let .columns(_, children):
        children.flatMap(tapActions)
    case let .centered(children):
        children.flatMap(tapActions)
    case let .region(_, _, child):
        tapActions(child)
    case let .card(_, _, _, _, child):
        tapActions(child)
    case let .scroll(_, child):
        tapActions(child)
    default:
        []
    }
}

private func collectHolds(_ node: WidgetView, into holds: inout [String?]) {
    switch node {
    case let .tappable(_, hold, child):
        holds.append(hold)
        collectHolds(child, into: &holds)
    case let .stack(_, _, children):
        for child in children { collectHolds(child, into: &holds) }
    case let .columns(_, children):
        for child in children { collectHolds(child, into: &holds) }
    case let .centered(children):
        for child in children { collectHolds(child, into: &holds) }
    case let .region(_, _, child):
        collectHolds(child, into: &holds)
    case let .card(_, _, _, _, child):
        collectHolds(child, into: &holds)
    case let .scroll(_, child):
        collectHolds(child, into: &holds)
    default:
        break
    }
}

private func snapshotContent(_ dashboard: Dashboard, _ id: WidgetID) -> WidgetContent {
    dashboard.attachedWidgetSnapshots.first { $0.id == id }?.content ?? WidgetContent(primaryText: "")
}

