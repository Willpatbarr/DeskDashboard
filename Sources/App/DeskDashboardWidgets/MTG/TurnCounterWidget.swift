// TurnCounterWidget.swift — MTG: the shared turn number, tappable to advance or reset.

import DashboardKit

/// The turn number, shared by the whole table (unlike life, which is per seat).
///
/// Reads and writes the same `MTGGameService` the life counters use, so advancing
/// the turn is visible to every seat and survives switching arrangements.
public struct TurnCounterWidget: RenderableWidget, InteractiveWidget {
    public enum Action {
        public static let advance = "turn.advance"
        public static let reset = "turn.reset"
    }

    public var configuration: WidgetConfiguration
    private let game: any MTGGameService

    public init(
        id: String = "turn",
        game: any MTGGameService,
        configuration: WidgetConfiguration? = nil
    ) {
        self.configuration = configuration ?? WidgetConfiguration(
            preferredID: WidgetID(id),
            title: "Turn",
            size: .medium,
            refreshRate: .seconds(1),
            layout: .turnCounter
        )
        self.game = game
    }

    public func render(environment: DashboardEnvironment) -> WidgetContent {
        WidgetContent(
            title: configuration.title,
            primaryText: "\(game.turn)",
            // RESET only exists once there's something to reset — matching the old
            // hand-built screen, where the affordance appeared from turn 1.
            accessoryText: game.turn >= 1 ? "RESET" : nil
        )
    }

    public func handle(action: String, environment: DashboardEnvironment) {
        switch action {
        case Action.advance: game.advanceTurn()
        case Action.reset:   game.resetTurn()
        default: break
        }
    }
}
