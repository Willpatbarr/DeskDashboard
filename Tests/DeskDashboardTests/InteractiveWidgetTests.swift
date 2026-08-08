// InteractiveWidgetTests.swift — Tests: taps reach a widget and change what it renders.

import DashboardKit
import DeskDashboardWidgets
import Testing

@Test func lifeCounterStartsAtTheFormatsStartingTotal() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    #expect(content(dashboard, id)?.primaryText == "40")
}

@Test func tappingIncrementAndDecrementChangesTheRenderedTotal() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: id)
    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: id)
    dashboard.perform(action: LifeCounterWidget.Action.increment, on: id)

    // The whole point of the round trip: state changed in the SERVICE, and shows
    // up through the ordinary render path rather than any renderer-side shortcut.
    #expect(content(dashboard, id)?.primaryText == "39")
}

@Test func tappingTheTotalResetsIt() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: id)
    dashboard.perform(action: LifeCounterWidget.Action.reset, on: id)

    #expect(content(dashboard, id)?.primaryText == "40")
}

@Test func resetAffordanceIsAbsentAtTheStartingTotal() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    // Nothing to reset yet, so the badge stays off a fresh board.
    #expect(content(dashboard, id)?.accessoryText == nil)
}

@Test func resetAffordanceAppearsOnceLifeHasMovedAndGoesAwayAgain() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: id)
    #expect(content(dashboard, id)?.accessoryText != nil)

    dashboard.perform(action: LifeCounterWidget.Action.reset, on: id)
    #expect(content(dashboard, id)?.accessoryText == nil)
}

@Test func resetAffordanceTracksDistanceFromStartingTotalNotDirection() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    // Gaining life is just as resettable as losing it.
    dashboard.perform(action: LifeCounterWidget.Action.incrementTen, on: id)
    #expect(content(dashboard, id)?.primaryText == "50")
    #expect(content(dashboard, id)?.accessoryText != nil)

    // And a seat that wanders back to 40 on its own needs no badge.
    dashboard.perform(action: LifeCounterWidget.Action.decrementTen, on: id)
    #expect(content(dashboard, id)?.accessoryText == nil)
}

@Test func eachSeatsResetBadgeIsIndependent() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let one = dashboard.add(LifeCounterWidget(id: "life1", game: game))
    let two = dashboard.add(LifeCounterWidget(id: "life2", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: one)

    #expect(content(dashboard, one)?.accessoryText != nil)
    #expect(content(dashboard, two)?.accessoryText == nil)
}

@Test func noChangeIsShownBeforeAnythingHappens() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    #expect(content(dashboard, id)?.secondaryText == nil)
}

@Test func theChangeInProgressAccumulatesAcrossTaps() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: id)
    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: id)
    dashboard.perform(action: LifeCounterWidget.Action.decrementTen, on: id)

    // The point of the readout: you can see the hit without having memorised 40.
    #expect(content(dashboard, id)?.primaryText == "28")
    #expect(content(dashboard, id)?.secondaryText == "−12")
}

@Test func gainsAreSignedAndLossesUseTheMinusGlyphNotAHyphen() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.incrementTen, on: id)
    #expect(content(dashboard, id)?.secondaryText == "+10")

    // U+2212, the same glyph the decrement control draws.
    dashboard.perform(action: LifeCounterWidget.Action.decrementTen, on: id)
    dashboard.perform(action: LifeCounterWidget.Action.decrementTen, on: id)
    #expect(content(dashboard, id)?.secondaryText == "\u{2212}10")
}

@Test func aChangeThatNetsBackToZeroShowsNothing() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.increment, on: id)
    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: id)

    #expect(content(dashboard, id)?.primaryText == "40")
    #expect(content(dashboard, id)?.secondaryText == nil)
}

@Test func theChangeExpiresOnceItsWindowHasPassed() {
    // Window pinned to zero so the expiry is deterministic — no sleeping.
    let game = InMemoryMTGGameService(changeWindow: 0)
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: id)

    #expect(content(dashboard, id)?.primaryText == "39")   // life still moved
    #expect(content(dashboard, id)?.secondaryText == nil)  // but the readout is gone
}

@Test func resettingDiscardsTheChangeRatherThanLoggingIt() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.decrementTen, on: id)
    dashboard.perform(action: LifeCounterWidget.Action.reset, on: id)

    #expect(content(dashboard, id)?.primaryText == "40")
    #expect(content(dashboard, id)?.secondaryText == nil)
}

@Test func eachSeatsChangeReadoutIsIndependent() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let one = dashboard.add(LifeCounterWidget(id: "life1", game: game))
    let two = dashboard.add(LifeCounterWidget(id: "life2", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: one)

    #expect(content(dashboard, one)?.secondaryText == "−1")
    #expect(content(dashboard, two)?.secondaryText == nil)
}

@Test func seatsTrackTheirOwnLifeButShareOneGame() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let one = dashboard.add(LifeCounterWidget(id: "life1", game: game))
    let two = dashboard.add(LifeCounterWidget(id: "life2", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: one)

    #expect(content(dashboard, one)?.primaryText == "39")
    #expect(content(dashboard, two)?.primaryText == "40")   // untouched
}

@Test func unknownActionsAndIdsAreIgnoredRatherThanFatal() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    // A stale tap from a renderer must never bring the kiosk down.
    dashboard.perform(action: "nonsense", on: id)
    dashboard.perform(action: LifeCounterWidget.Action.increment, on: WidgetID("nobody"))

    #expect(content(dashboard, id)?.primaryText == "40")
}

@Test func aPlainWidgetIgnoresActionsEntirely() {
    // Non-interactive widgets stay one-way; routing an action at one is a no-op.
    var dashboard = Dashboard()
    let id = dashboard.add(ClockWidget())
    dashboard.perform(action: "life.increment", on: id)
    #expect(content(dashboard, id) != nil)
}

private func content(_ dashboard: Dashboard, _ id: WidgetID) -> WidgetContent? {
    dashboard.attachedWidgetSnapshots.first { $0.id == id }?.content
}

// MARK: - Turn counter

@Test func turnStartsAtZeroWithNoResetAffordance() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(TurnCounterWidget(game: game))

    #expect(content(dashboard, id)?.primaryText == "0")
    // Nothing to reset yet, so the layout gets no reset badge to draw.
    #expect(content(dashboard, id)?.accessoryText == nil)
}

@Test func advancingTheTurnRevealsTheResetAffordance() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(TurnCounterWidget(game: game))

    dashboard.perform(action: TurnCounterWidget.Action.advance, on: id)
    #expect(content(dashboard, id)?.primaryText == "1")
    #expect(content(dashboard, id)?.accessoryText == "RESET")

    dashboard.perform(action: TurnCounterWidget.Action.reset, on: id)
    #expect(content(dashboard, id)?.primaryText == "0")
    #expect(content(dashboard, id)?.accessoryText == nil)
}

@Test func turnIsSharedAcrossTheTableButLifeIsNot() {
    // The whole reason game state is a service: turn is common to every seat,
    // life is per seat. Both read the same game.
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let turn = dashboard.add(TurnCounterWidget(game: game))
    let seat = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: TurnCounterWidget.Action.advance, on: turn)
    dashboard.perform(action: LifeCounterWidget.Action.decrement, on: seat)

    #expect(content(dashboard, turn)?.primaryText == "1")
    #expect(content(dashboard, seat)?.primaryText == "39")
    #expect(game.turn == 1)
}

// MARK: - Hold to move by ten

@Test func holdingIncrementMovesByTen() {
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.incrementTen, on: id)
    #expect(content(dashboard, id)?.primaryText == "50")

    dashboard.perform(action: LifeCounterWidget.Action.decrementTen, on: id)
    dashboard.perform(action: LifeCounterWidget.Action.decrementTen, on: id)
    #expect(content(dashboard, id)?.primaryText == "30")
}

@Test func holdAndTapAreSeparateActionsOnTheSameRegion() {
    // A hold must not also fire the tap: the layout gives `+` two distinct action
    // names, and the widget maps them to different step sizes.
    let game = InMemoryMTGGameService()
    var dashboard = Dashboard()
    let id = dashboard.add(LifeCounterWidget(id: "life1", game: game))

    dashboard.perform(action: LifeCounterWidget.Action.increment, on: id)
    #expect(content(dashboard, id)?.primaryText == "41")
    dashboard.perform(action: LifeCounterWidget.Action.incrementTen, on: id)
    #expect(content(dashboard, id)?.primaryText == "51")
}

@Test func onlyThePlusAndMinusRespondToAHold() {
    // Reset and the turn actions carry `hold: nil`, so a long press there is inert
    // rather than silently doing something surprising. Two of them: the total and
    // the reset glyph under it both reset the seat.
    let plus = WidgetLayout.lifeCounter.makeView(WidgetContent(primaryText: "40"))
    var holds: [String?] = []
    collectHolds(plus, into: &holds)
    #expect(holds == ["life.incrementTen", nil, nil, "life.decrementTen"])
}

@Test func theTileHasTheSameNodesWhetherOrNotThereIsAnythingToShow() {
    // Not cosmetic: adding or removing a node mid-press rebuilds the widgets below
    // it, GTK cancels the gesture on the one being held, and the auto-repeat then
    // never receives a release. A hold on `−` that pushed life off 40 used to make
    // the reset glyph appear and run the seat away. See the layout's own note.
    let bare = WidgetLayout.lifeCounter.makeView(WidgetContent(primaryText: "40"))
    let full = WidgetLayout.lifeCounter.makeView(
        WidgetContent(primaryText: "28", secondaryText: "−12", accessoryText: "↺")
    )

    #expect(shape(of: bare) == shape(of: full))
}

/// The node tree with every string blanked — structure only, values ignored.
private func shape(of node: WidgetView) -> String {
    switch node {
    case .text: "text"
    case .badge: "badge"
    case .spacer: "spacer"
    case .divider: "divider"
    case .fittedText: "fitted"
    case .progressBar: "progress"
    case .playState: "playState"
    case let .tappable(action, hold, child):
        "tappable(\(action),\(hold ?? "-"))[\(shape(of: child))]"
    case let .centered(children):
        "centered[\(children.map(shape(of:)).joined(separator: ","))]"
    case let .stack(axis, _, children):
        "stack(\(axis))[\(children.map(shape(of:)).joined(separator: ","))]"
    case let .region(minWidth, minHeight, child):
        "region(\(minWidth),\(minHeight))[\(shape(of: child))]"
    }
}

private func collectHolds(_ node: WidgetView, into holds: inout [String?]) {
    switch node {
    case let .tappable(_, hold, child):
        holds.append(hold)
        collectHolds(child, into: &holds)
    case let .stack(_, _, children):
        for child in children { collectHolds(child, into: &holds) }
    case let .centered(children):
        for child in children { collectHolds(child, into: &holds) }
    case let .region(_, _, child):
        collectHolds(child, into: &holds)
    default:
        break
    }
}
