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
    // rather than silently doing something surprising.
    let plus = WidgetLayout.lifeCounter.makeView(WidgetContent(primaryText: "40"))
    var holds: [String?] = []
    collectHolds(plus, into: &holds)
    #expect(holds == ["life.incrementTen", nil, "life.decrementTen"])
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
    default:
        break
    }
}
