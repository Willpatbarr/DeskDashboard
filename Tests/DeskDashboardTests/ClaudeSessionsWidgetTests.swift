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

    // One entry per column the daemon pushed, each holding only its real
    // sessions — the columns scroll, so blank padding would be dead space.
    #expect(model.grid.count == 3)
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

@Test func longTitlesAreTruncatedToTheColumnWidth() {
    let long = String(repeating: "x", count: 60)
    let session = ClaudeSession(id: "a", title: long, column: "working", agentCount: 2)

    let threeUp = ClaudeSessionsWidgetModel.rowTitle(session, columns: 3)
    let fiveUp = ClaudeSessionsWidgetModel.rowTitle(session, columns: 5)

    #expect(threeUp.hasSuffix("… ⚙2"))
    #expect(threeUp.count <= ClaudeSessionsWidgetModel.maxTitleLength(columns: 3) + 3)
    // A narrower board truncates harder — the title has to fit its column, and
    // GTK will not ellipsize it for us.
    #expect(fiveUp.count < threeUp.count)
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

// MARK: - Rail filters

@Test func bucketsAreReadOffTheProjectFolderAndTheRawTitle() {
    // `project` is the session directory's basename, so the MemberTools family —
    // sibling clones and per-ticket worktrees alike — is a prefix match.
    let clone = ClaudeSession(id: "a", title: "A", project: "MemberTools-Android", column: "working")
    let worktree = ClaudeSession(
        id: "b", title: "B", project: "MemberTools-Android-MMA-5381", column: "working"
    )
    let shared = ClaudeSession(id: "c", title: "C", project: "MemberTools-Mobile-Shared", column: "working")
    let elsewhere = ClaudeSession(id: "d", title: "D", project: "android-week-view", column: "working")
    let homeless = ClaudeSession(id: "e", title: "E", column: "working")   // no project at all

    #expect([clone, worktree, shared].allSatisfy(ClaudeSessionFilter.isMemberTools))
    #expect(!ClaudeSessionFilter.isMemberTools(elsewhere))
    #expect(!ClaudeSessionFilter.isMemberTools(homeless))

    // A slash title is the skill signal; a bare "/" is not one.
    let skill = ClaudeSession(id: "f", title: "/kickoff MMA-6006", column: "working")
    #expect(ClaudeSessionFilter.isSkill(skill))
    #expect(!ClaudeSessionFilter.isSkill(clone))
    #expect(!ClaudeSessionFilter.isSkill(ClaudeSession(id: "g", title: "/", column: "working")))

    // `...` is defined as neither of the others, so a MemberTools session that
    // is ALSO a skill session belongs to two buckets, never to this one.
    let both = ClaudeSession(id: "h", title: "/preflight", project: "MemberTools-Android", column: "working")
    #expect(ClaudeSessionFilter.other.matches(elsewhere))
    #expect(ClaudeSessionFilter.other.matches(homeless))
    #expect(!ClaudeSessionFilter.other.matches(both))
    #expect(ClaudeSessionFilter.memberTools.matches(both))
    #expect(ClaudeSessionFilter.skills.matches(both))
}

@Test func noPillLitShowsEverythingAndAllThreeIsTheSameBoard() {
    let sessions = [
        ClaudeSession(id: "a", title: "A", project: "MemberTools-Android", column: "working"),
        ClaudeSession(id: "b", title: "/kickoff X", project: "XMLWiki", column: "working"),
        ClaudeSession(id: "c", title: "C", project: "DeskDashboard", column: "idle"),
    ]

    // The empty set is the RESTING state, not "show nothing" — the board can
    // never be filtered down to blank.
    #expect(sessions.allSatisfy { ClaudeSessionFilter.allows($0, []) })
    // The buckets are exhaustive, so lighting all three is lighting none.
    #expect(sessions.allSatisfy { ClaudeSessionFilter.allows($0, Set(ClaudeSessionFilter.allCases)) })
    // Two lit is the union of the two, and nothing else.
    let union = sessions.filter { ClaudeSessionFilter.allows($0, [.memberTools, .skills]) }
    #expect(union.map(\.id) == ["a", "b"])
}

@Test func aFilterTapNarrowsTheGridAndEveryCountWithIt() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "mt1", title: "One", project: "MemberTools-Android", column: "working"),
        ClaudeSession(id: "mt2", title: "Two", project: "MemberTools-Mobile-Shared", column: "idle"),
        ClaudeSession(id: "sk", title: "/kickoff MMA-6006", project: "DeskDashboard", column: "working"),
        ClaudeSession(id: "other", title: "Plain", project: "XMLWiki", column: "idle"),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    // Read through the SNAPSHOT rather than the model, because that is the whole
    // trip the rail's tap actually takes: action → widget → model → repaint.
    dashboard.perform(action: "claude.filters.MT", on: id)
    var content = snapshotContent(dashboard, id)
    #expect(sessionIDs(content) == ["mt1", "mt2"])
    // Header counts and the counts line report what is ON SCREEN, not the push's
    // totals — a header reading 2 over one visible card would be a lie.
    #expect(columnCounts(content) == ["1", "0", "1"])
    #expect(content.primaryText == "1 working · 0 needs you · 1 idle")

    // The union of two buckets — column-major, so the idle MemberTools card is
    // last even though it was pushed second.
    dashboard.perform(action: "claude.filters.MT,/s", on: id)
    content = snapshotContent(dashboard, id)
    #expect(sessionIDs(content) == ["mt1", "sk", "mt2"])
    #expect(content.primaryText == "2 working · 0 needs you · 1 idle")

    // An empty suffix is how the rail says every pill went dark.
    dashboard.perform(action: "claude.filters.", on: id)
    content = snapshotContent(dashboard, id)
    #expect(sessionIDs(content) == ["mt1", "sk", "mt2", "other"])
    #expect(content.primaryText == "2 working · 0 needs you · 2 idle")
}

private func sessionIDs(_ content: WidgetContent) -> [String] {
    content.metadata.map { ClaudeCard($0.value)[.sessionID] }
}

private func columnCounts(_ content: WidgetContent) -> [String] {
    ClaudeColumnHeader.all(in: content.secondaryText ?? "").map { $0[.count] }
}

@Test func theSelectionSurvivesTheWireInAStableOrder() {
    // Ordering comes from `allCases`, never from `Set` iteration, so the same
    // lit pills always produce the same action string.
    let all = Set(ClaudeSessionFilter.allCases)
    #expect(ClaudeSessionFilter.encode(all) == "MT,/s,...")
    #expect(ClaudeSessionFilter.encode([.other, .memberTools]) == "MT,...")
    #expect(ClaudeSessionFilter.decode("MT,/s,...") == all)
    #expect(ClaudeSessionFilter.decode("") == [])
    // Junk from an older or newer rail is dropped rather than blanking the board.
    #expect(ClaudeSessionFilter.decode("MT,nonsense") == [.memberTools])
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

@Test func noCardHoldsAtAll() {
    // This tile has VARIABLE node counts (columns scroll, so cards are not
    // padded to a fixed shape). `lifeCounter`'s fixed-shape rule exists because
    // a node inserted mid-press makes GTK cancel a HOLD's gesture, so its
    // auto-repeat never receives a release and runs away.
    //
    // Nothing here holds, so that failure has nothing to act on. This used to
    // assert the weaker "no hold REPEATS" — true while a long press opened the
    // detail panel — and the tap menu retired the long press entirely. Losing it
    // also retires the renderer's tap-vs-hold-vs-drag arbitration for this
    // board, so the invariant is worth keeping strict.
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
        ClaudeSession(id: "local_b", title: "Two", column: "needs-you", ageSeconds: 40),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date(timeIntervalSinceNow: 2))

    var holds: [HoldAction?] = []
    collectHolds(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id)), into: &holds)

    #expect(!holds.isEmpty)
    #expect(holds.allSatisfy { $0 == nil })
}

// MARK: - Detail panel

@Test func openingDetailPacksTheSessionsFullDetailAndItsAgents() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(
            id: "local_a", title: String(repeating: "y", count: 80),
            project: "MemberTools-Android", model: "claude-opus-5",
            stage: "review", blockedOn: "changes-requested", branch: "MMA-5466",
            prNumber: 2070, prState: "OPEN", prReviewDecision: "CHANGES_REQUESTED",
            column: "needs-you", agentCount: 1, lastActivity: "Running gradle build",
            ageSeconds: 30,
            agents: [
                ClaudeSessionAgent(label: "Explore the layout", agentType: "Explore",
                                   running: true, seconds: 12),
                ClaudeSessionAgent(label: "Fix the tables", agentType: "general-purpose",
                                   running: false, seconds: 240, failed: true),
            ],
            repo: "org/MemberTools-Android", base: "develop", worktree: true,
            effort: "high", permissionMode: "plan", planName: "MMA-5466-plan"
        ),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    // Nothing open: metadata is cards only.
    #expect(snapshotContent(dashboard, id).metadata.count == 1)

    dashboard.perform(action: "claude.detail.local_a", on: id)
    let content = snapshotContent(dashboard, id)
    // One card, one detail block, two agents.
    #expect(content.metadata.count == 4)

    let detail = ClaudeDetail(content.metadata[1].value)
    #expect(detail[.sessionID] == "local_a")
    // The panel undoes the card's truncation — that is what it is for.
    #expect(detail[.title] == String(repeating: "y", count: 80))
    #expect(detail[.activity] == "Running gradle build")
    #expect(detail[.repo] == "org/MemberTools-Android")
    #expect(detail[.branch] == "MMA-5466")
    #expect(detail[.base] == "develop")
    #expect(detail[.worktree] == "1")
    #expect(detail[.pullRequest] == "#2070")
    #expect(detail[.prReviewDecision] == "CHANGES_REQUESTED")
    // The panel's title reads `name — COLUMN`, so the column it sits in travels
    // with it, looked up from the board's own columns rather than the id.
    #expect(detail[.columnLabel] == "Needs You")
    #expect(detail[.effort] == "high")
    #expect(detail[.permissionMode] == "plan")
    #expect(detail[.planName] == "MMA-5466-plan")

    let first = ClaudeAgentRow(content.metadata[2].value)
    #expect(first[.label] == "Explore the layout")
    #expect(first[.agentType] == "Explore")
    #expect(first[.running] == "1")
    #expect(first[.seconds] == "12")
    let second = ClaudeAgentRow(content.metadata[3].value)
    // A FINISHED agent still travels — the whole reason `agentRuns` exists
    // separately from the in-flight `agentCount`.
    #expect(second[.running].isEmpty)
    #expect(second[.failed] == "1")
    #expect(second[.seconds] == "240")
}

@Test func openingAndClosingThePanelIsSeparateFromFocusing() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    dashboard.perform(action: "claude.detail.local_a", on: id)
    #expect(snapshotContent(dashboard, id).metadata.count == 2)

    // `claude.detail.close` shares the open prefix, so this pins that it is
    // read as a close and never as a session id.
    dashboard.perform(action: "claude.detail.close", on: id)
    #expect(snapshotContent(dashboard, id).metadata.count == 1)

    // A tap still focuses on the Mac, and opens nothing.
    dashboard.perform(action: "claude.focus.local_a", on: id)
    #expect(service.focused == ["local_a"])
    #expect(snapshotContent(dashboard, id).metadata.count == 1)
}

@Test func aPanelClosesItselfWhenItsSessionLeavesTheBoard() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
        ClaudeSession(id: "local_b", title: "Two", column: "working", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())
    dashboard.perform(action: "claude.detail.local_a", on: id)
    #expect(snapshotContent(dashboard, id).metadata.count == 3) // 2 cards + detail

    // The session finishes and the daemon stops sending it. The panel must go
    // with it rather than freezing over a board that has moved on.
    service.stored = reading([
        ClaudeSession(id: "local_b", title: "Two", column: "working", ageSeconds: 5),
    ])
    dashboard.tick(at: Date(timeIntervalSinceNow: 2))
    #expect(snapshotContent(dashboard, id).metadata.count == 1)
}

@Test func aFilterDoesNotCloseAnOpenPanel() {
    // The panel is matched against the whole reading, not the filtered view:
    // tapping a rail pill while a panel is up shouldn't yank it away.
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", project: "XMLWiki", column: "working"),
        ClaudeSession(id: "mt", title: "Two", project: "MemberTools-Android", column: "working"),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    dashboard.perform(action: "claude.detail.local_a", on: id)
    dashboard.perform(action: "claude.filters.MT", on: id)

    let content = snapshotContent(dashboard, id)
    // One card left on the board, and the panel is still the one that was open.
    #expect(content.metadata.count == 2)
    #expect(ClaudeDetail(content.metadata[1].value)[.sessionID] == "local_a")
}

@Test func thePanelLayersOverTheBoardOnlyWhileOneIsOpen() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    // No layer at rest. An overlay is a real widget on GTK and swallows every
    // tap beneath it, so one that existed year-round would kill the board.
    #expect(!isLayered(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))))

    dashboard.perform(action: "claude.detail.local_a", on: id)
    let open = WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))
    #expect(isLayered(open))

    // The way out is the node's OWN dismiss action, not a tappable buried in
    // the panel. The renderer draws the scrim and the close control from it —
    // the panel's tree deliberately holds neither, because a full-bleed dismiss
    // target ate the agent list's scroll gestures and a close button placed
    // beside the `.columns` collapsed it.
    #expect(dismissAction(of: open) == "claude.detail.close")
    // The panel's own tree holds NO dismiss target. The renderer draws both the
    // scrim and the close button from the action above — a full-bleed tappable
    // in here ate the agent list's scroll gestures, and a close button beside
    // the `.columns` starved it.
    #expect(!tapActions(open).contains("claude.detail.close"))
}

private func isLayered(_ node: WidgetView) -> Bool {
    if case .layered = node { return true }
    return false
}

private func dismissAction(of node: WidgetView) -> String? {
    if case let .layered(_, _, dismiss, _, _) = node { return dismiss }
    return nil
}

private func layerAnchor(of node: WidgetView) -> LayerAnchor? {
    if case let .layered(_, _, _, anchor, _) = node { return anchor }
    return nil
}

/// Tap actions of the LAYER only, not the board underneath it — the board's own
/// cards are tappable too, and this is about what the panel offers.
private func panelActions(of node: WidgetView) -> [String] {
    guard case let .layered(_, _, _, _, panel) = node else { return [] }
    return tapActions(panel)
}

// MARK: - Tap menu

@Test func tappingACardRaisesAMenuBesideIt() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    // No layer at rest — the untappable-board hazard applies to the menu just
    // as it does to the detail panel.
    #expect(!isLayered(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))))

    dashboard.perform(action: "claude.menu.local_a", on: id)
    let open = WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))

    #expect(isLayered(open))
    // A popover beside the touch, not a screen-taking modal.
    #expect(layerAnchor(of: open) == .lastTouch(side: .trailing))
    #expect(dismissAction(of: open) == "claude.menu.close")
    // Exactly two rows, and they name the two things a session can do.
    #expect(panelActions(of: open) == ["claude.focus.local_a", "claude.detail.local_a"])
}

@Test func theMenuOpensAwayFromTheEdgeOfTheStrip() {
    // A menu on the rightmost column has to open leftward or it runs off the
    // strip; every other column opens to the right.
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "first", title: "One", column: "working", ageSeconds: 5),
        ClaudeSession(id: "last", title: "Two", column: "idle", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    dashboard.perform(action: "claude.menu.first", on: id)
    #expect(layerAnchor(of: WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id)))
        == .lastTouch(side: .trailing))

    // `idle` is the last of the three columns this fixture declares.
    dashboard.perform(action: "claude.menu.last", on: id)
    #expect(layerAnchor(of: WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id)))
        == .lastTouch(side: .leading))
}

@Test func theMenusRowsDoWhatTheySayAndTakeTheMenuWithThem() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    // Open focuses on the Mac and puts the menu away.
    dashboard.perform(action: "claude.menu.local_a", on: id)
    dashboard.perform(action: "claude.focus.local_a", on: id)
    #expect(service.focused == ["local_a"])
    #expect(!isLayered(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))))

    // Details swaps the menu for the full panel — never both at once.
    dashboard.perform(action: "claude.menu.local_a", on: id)
    dashboard.perform(action: "claude.detail.local_a", on: id)
    let detail = WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))
    #expect(layerAnchor(of: detail) == .screenCenter)
    #expect(dismissAction(of: detail) == "claude.detail.close")
}

@Test func tappingTheSameCardTwiceClosesItsMenu() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
        ClaudeSession(id: "local_b", title: "Two", column: "working", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    dashboard.perform(action: "claude.menu.local_a", on: id)
    #expect(isLayered(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))))

    // The same card again is a toggle, not a re-open.
    dashboard.perform(action: "claude.menu.local_a", on: id)
    #expect(!isLayered(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))))

    // A DIFFERENT card moves the menu rather than closing it.
    dashboard.perform(action: "claude.menu.local_a", on: id)
    dashboard.perform(action: "claude.menu.local_b", on: id)
    let moved = WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))
    #expect(panelActions(of: moved) == ["claude.focus.local_b", "claude.detail.local_b"])
}

@Test func closingTheMenuIsNotReadAsASessionID() {
    // `claude.menu.close` shares the open prefix, exactly as the detail pair
    // does, so this pins the handler's ordering.
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    dashboard.perform(action: "claude.menu.local_a", on: id)
    dashboard.perform(action: "claude.menu.close", on: id)
    #expect(!isLayered(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))))

    // An empty suffix names no session and must not open anything.
    dashboard.perform(action: "claude.menu.", on: id)
    #expect(!isLayered(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))))
}

@Test func aMenuClosesItselfWhenItsSessionLeavesTheBoard() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_a", title: "One", column: "working", ageSeconds: 5),
        ClaudeSession(id: "local_b", title: "Two", column: "working", ageSeconds: 5),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())
    dashboard.perform(action: "claude.menu.local_a", on: id)
    #expect(isLayered(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))))

    service.stored = reading([
        ClaudeSession(id: "local_b", title: "Two", column: "working", ageSeconds: 5),
    ])
    dashboard.tick(at: Date(timeIntervalSinceNow: 2))
    #expect(!isLayered(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))))
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

    // Each card's action carries its own session — a tap raises that session's
    // menu — and the walk finds every column's slice of the flat metadata list
    // (`local_c` is in column three).
    #expect(oneCard == ["claude.menu.local_a"])
    #expect(threeCards == [
        "claude.menu.local_a", "claude.menu.local_b", "claude.menu.local_c",
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
    case let .card(_, child):
        tapActions(child)
    case let .scroll(_, child):
        tapActions(child)
    case let .layered(base, _, _, _, panel):
        tapActions(base) + tapActions(panel)
    default:
        []
    }
}

private func collectHolds(_ node: WidgetView, into holds: inout [HoldAction?]) {
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
    case let .card(_, child):
        collectHolds(child, into: &holds)
    case let .scroll(_, child):
        collectHolds(child, into: &holds)
    case let .layered(base, _, _, _, panel):
        collectHolds(base, into: &holds)
        collectHolds(panel, into: &holds)
    default:
        break
    }
}

private func snapshotContent(_ dashboard: Dashboard, _ id: WidgetID) -> WidgetContent {
    dashboard.attachedWidgetSnapshots.first { $0.id == id }?.content ?? WidgetContent(primaryText: "")
}


// MARK: - Stage and PR (the reshaped session model)

@Test func blockedOnOutranksTheLegacyAliasAndStalled() {
    // `blockedOn` is the daemon's real signal; `askPending` is the alias it
    // keeps sending so an un-rebuilt Pi still flags questions. A session that
    // is BOTH blocked and quiet reports why it's blocked, not that it's quiet.
    let plan = ClaudeSession(
        id: "a", title: "A", blockedOn: "plan", column: "needs-you", stalled: true
    )
    let legacy = ClaudeSession(id: "b", title: "B", column: "needs-you", askPending: true)
    let quiet = ClaudeSession(id: "c", title: "C", column: "working", stalled: true)
    let calm = ClaudeSession(id: "d", title: "D", column: "idle")

    #expect(ClaudeSessionsWidgetModel.flagKind(plan) == "plan")
    #expect(ClaudeSessionsWidgetModel.flagKind(legacy) == "question")
    #expect(ClaudeSessionsWidgetModel.flagKind(quiet) == "stalled")
    #expect(ClaudeSessionsWidgetModel.flagKind(calm) == "")
}

@Test func stageAndPullRequestSurviveThePackingRoundTrip() {
    // The packing is positional, so this is the test that a field added in one
    // place and read in another still lines up — see `ClaudeCardPacking`.
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(
            id: "local_a", title: "Under review", project: "MemberTools",
            model: "claude-opus-5", stage: "review", blockedOn: "changes-requested",
            branch: "MMA-5466", prNumber: 2070, prState: "OPEN",
            prReviewDecision: "CHANGES_REQUESTED", column: "needs-you", ageSeconds: 30
        ),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date(timeIntervalSinceNow: 2))

    let content = snapshotContent(dashboard, id)
    let card = ClaudeCard(content.metadata[0].value)

    #expect(card[.sessionID] == "local_a")
    #expect(card[.stage] == "review")
    #expect(card[.pullRequest] == "#2070")
    #expect(card[.changesRequested] == "1")
    #expect(card[.flag] == "changes-requested")
    #expect(card[.model] == "opus-5")
}

@Test func aSessionWithNoPullRequestPacksEmptyFields() {
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(id: "local_b", title: "Just working", column: "working", ageSeconds: 3),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date(timeIntervalSinceNow: 2))

    let card = ClaudeCard(snapshotContent(dashboard, id).metadata[0].value)
    #expect(card[.pullRequest].isEmpty)
    #expect(card[.changesRequested].isEmpty)
    #expect(card[.stage].isEmpty)
}

// MARK: - Theming

@Test func structureFollowsTheThemeAndMeaningDoesNot() {
    // The invariant this board is built on, and the one it originally got
    // wrong: anything STRUCTURAL (wells, cards, rules, body text) names a
    // theme token so the hue pill moves it, while anything that carries
    // INFORMATION (attention bar, flags, PR, column accents) is a literal that
    // must not move when the theme does.
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(
            id: "local_a", title: "Under review", project: "Repo",
            model: "claude-opus-5", blockedOn: "changes-requested",
            prNumber: 2070, prState: "OPEN", prReviewDecision: "CHANGES_REQUESTED",
            column: "needs-you", ageSeconds: 30
        ),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date(timeIntervalSinceNow: 2))
    let tree = WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id))

    var fills: [ColorToken] = []
    var inks: [ColorToken] = []
    collectColors(tree, fills: &fills, inks: &inks)

    // Every surface the board paints is the theme's.
    #expect(!fills.isEmpty)
    #expect(fills.allSatisfy { isThemed($0) || $0 == .surface || $0 == .surfaceRaised })
    #expect(fills.contains(.surface))       // the column wells
    #expect(fills.contains(.surfaceRaised)) // the cards

    // Text is a mix, and both halves must be present: themed body text, and
    // the fixed colours that mean "changes requested" and "there is a PR".
    #expect(inks.contains { isThemed($0) })
    #expect(inks.contains(.hex("#f87171")))  // changes requested stays red
    #expect(inks.contains(.hex("#60a5fa")))  // a PR number stays blue
}

private func isThemed(_ token: ColorToken) -> Bool {
    if case .hex = token { return false }
    return true
}

// MARK: - Attention colour and producer staleness

@Test func theAccentBarFallsBackToTheAttentionPaletteNotTheColumnAccent() {
    // The fallback used to look `attention` up among COLUMN ids. On a
    // stage-based board those sets are disjoint, so it always resolved to ""
    // and every card in a column came out the column's own colour. This pins
    // the local palette instead — a push that omits `attentionColor` must still
    // paint a running session green.
    let stageBoard = ClaudeSessionsReading(
        columns: [
            ClaudeSessionColumn(id: "scratch", label: "Scratch", colorHex: "#8b929c"),
            ClaudeSessionColumn(id: "planning", label: "Planning", colorHex: "#c4b5fd"),
            ClaudeSessionColumn(id: "building", label: "In Worktree", colorHex: "#5eead4"),
        ],
        sessions: [
            ClaudeSession(
                id: "local_a", title: "One", attention: "working",
                column: "planning", ageSeconds: 5
            ),
        ],
        receivedAt: Date()
    )
    let service = FixedClaudeSessionsService(stageBoard)
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    dashboard.perform(action: "claude.detail.local_a", on: id)
    let card = ClaudeCard(snapshotContent(dashboard, id).metadata[0].value)
    #expect(card[.accentHex] == "#4ade80")
    // Not the column it happens to sit in.
    #expect(card[.accentHex] != "#c4b5fd")
}

@Test func aProducerBehindOnTheWireShapeOutranksAStaleReading() {
    // Absent/old `wireVersion` means the Mac is running pre-restart code and
    // silently omitting fields. That degrades gracefully by design, which is
    // exactly what makes it invisible — so it gets the louder word, even when
    // the reading is ALSO old.
    var behind = reading([])
    behind.wireVersion = ClaudeSessionsReading.currentWireVersion - 1
    behind.receivedAt = Date(timeIntervalSinceNow: -300)
    let service = FixedClaudeSessionsService(behind)
    let model = ClaudeSessionsWidgetModel(service: service)
    model.refresh(at: Date())
    #expect(model.statusFlag == "OLD MAC")

    // Current producer, nothing pushed lately: the symptom, not the cause.
    var quiet = reading([])
    quiet.receivedAt = Date(timeIntervalSinceNow: -300)
    service.stored = quiet
    model.refresh(at: Date())
    #expect(model.statusFlag == "STALE")
    #expect(model.isStale)

    // Healthy on both counts: no badge at all.
    service.stored = reading([])
    model.refresh(at: Date())
    #expect(model.statusFlag == nil)
}

@Test func theHeaderBadgeShowsWhateverTheModelFlagged() {
    // Pins the wiring: the widget hands `statusFlag` straight to
    // `accessoryText`, which the layout draws in the first column's header.
    var behind = reading([])
    behind.wireVersion = ClaudeSessionsReading.currentWireVersion - 1
    let service = FixedClaudeSessionsService(behind)
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())

    #expect(snapshotContent(dashboard, id).accessoryText == "OLD MAC")
}

@Test func aFinishedAgentsBarIsNotTheRunningGreen() {
    // The bar is the state signal, so it must come from the theme-independent
    // attention palette. "Done" once used the theme's `muted`, which under the
    // Green theme is #9cd09d — near enough to the in-flight #4ade80 that every
    // finished agent read as still running.
    let service = FixedClaudeSessionsService(reading([
        ClaudeSession(
            id: "local_a", title: "One", column: "working", agentCount: 1, ageSeconds: 5,
            agents: [
                ClaudeSessionAgent(label: "Still going", agentType: "Explore",
                                   running: true, seconds: 12),
                ClaudeSessionAgent(label: "All done", agentType: "Explore",
                                   running: false, seconds: 240),
            ]
        ),
    ]))
    var dashboard = Dashboard()
    let id = dashboard.add(ClaudeSessionsWidget().id("claude").service(service))
    dashboard.tick(at: Date())
    dashboard.perform(action: "claude.detail.local_a", on: id)

    var accents: [ColorToken] = []
    collectAccents(WidgetLayout.claudeSessions.makeView(snapshotContent(dashboard, id)), into: &accents)
    let hexes = accents.compactMap { token -> String? in
        if case let .hex(value) = token { return value }
        return nil
    }
    #expect(hexes.contains("#4ade80"))   // the running one
    #expect(hexes.contains("#6b7280"))   // the finished one, grey not green
}

/// Every card accent in the tree, for state-colour assertions.
private func collectAccents(_ node: WidgetView, into accents: inout [ColorToken]) {
    switch node {
    case let .card(style, child):
        if let accent = style.accent { accents.append(accent) }
        collectAccents(child, into: &accents)
    case let .stack(_, _, children), let .columns(_, children), let .centered(children):
        for child in children { collectAccents(child, into: &accents) }
    case let .tappable(_, _, child), let .region(_, _, child), let .scroll(_, child):
        collectAccents(child, into: &accents)
    case let .layered(base, _, _, _, panel):
        // The agent cards live in the PANEL, not the board underneath.
        collectAccents(base, into: &accents)
        collectAccents(panel, into: &accents)
    default:
        break
    }
}

/// Card/well fills and text colours, gathered separately.
private func collectColors(_ node: WidgetView, fills: inout [ColorToken], inks: inout [ColorToken]) {
    switch node {
    case let .card(style, child):
        fills.append(style.fill)
        collectColors(child, fills: &fills, inks: &inks)
    case let .coloredText(_, _, color):
        inks.append(color)
    case let .stack(_, _, children), let .columns(_, children), let .centered(children):
        for child in children { collectColors(child, fills: &fills, inks: &inks) }
    case let .tappable(_, _, child), let .region(_, _, child), let .scroll(_, child):
        collectColors(child, fills: &fills, inks: &inks)
    default:
        break
    }
}
