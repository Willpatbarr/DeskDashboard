// LifeCounterWidget.swift — MTG: one player's life total, with tappable +/− and reset.

import DashboardKit

/// One player's life total. Instantiate one per seat with a distinct id — the id
/// is also the key its life is stored under in `MTGGameService`.
///
/// Interactive rather than display-only: its layout marks the `+`, `−` and the
/// total itself as tappable, and `handle(action:environment:)` applies the change
/// to the service. The new total appears on the next tick like any other reading,
/// so the round trip is the ordinary snapshot path — nothing bypasses it.
public struct LifeCounterWidget: RenderableWidget, InteractiveWidget {
    /// Action names its layout raises; also what `handle` switches on.
    public enum Action {
        public static let increment = "life.increment"
        public static let decrement = "life.decrement"
        /// Hold variants — a long press on `+`/`−` moves ten at a time, which is
        /// what a 40-life format needs when someone takes a big hit.
        public static let incrementTen = "life.incrementTen"
        public static let decrementTen = "life.decrementTen"
        public static let reset = "life.reset"
    }

    public var configuration: WidgetConfiguration
    /// The game this seat belongs to. Injected by the composition rather than
    /// resolved from the environment, so all five MTG widgets share one instance.
    private let game: any MTGGameService

    public init(
        id: String,
        game: any MTGGameService,
        configuration: WidgetConfiguration? = nil
    ) {
        self.configuration = configuration ?? WidgetConfiguration(
            preferredID: WidgetID(id),
            size: .medium,
            refreshRate: .seconds(1),
            layout: .lifeCounter
        )
        self.game = game
    }

    /// Which seat's life this shows — the widget's own id.
    private var player: String {
        configuration.preferredID?.rawValue ?? "life"
    }

    public func render(environment: DashboardEnvironment) -> WidgetContent {
        let life = game.life(for: player)
        return WidgetContent(
            title: configuration.title,
            primaryText: "\(life)",
            // The running total of the adjustment in progress, shown beside the life
            // total until it expires. The service owns both the arithmetic and the
            // expiry; the widget only formats.
            secondaryText: game.recentLifeChange(for: player).map(Self.changeLabel),
            // The reset affordance only exists once this seat has something to
            // reset, matching the turn counter's RESET badge appearing from turn 1.
            // Deciding *when* is the widget's call; the layout just draws whatever
            // accessory it is handed.
            accessoryText: life == game.startingLife ? nil : Self.resetGlyph
        )
    }

    /// The reset badge's label. A glyph rather than the turn tile's word, because a
    /// life tile has three controls stacked in one column and a fourth word would
    /// read as another value.
    private static let resetGlyph = "↺"

    /// `+3` / `−5`. The minus is U+2212, matching the decrement control's glyph
    /// rather than a hyphen, so the two read as the same character on the tile.
    private static func changeLabel(_ change: Int) -> String {
        change > 0 ? "+\(change)" : "−\(abs(change))"
    }

    public func handle(action: String, environment: DashboardEnvironment) {
        switch action {
        case Action.increment:    game.adjustLife(for: player, by: +1)
        case Action.decrement:    game.adjustLife(for: player, by: -1)
        case Action.incrementTen: game.adjustLife(for: player, by: +10)
        case Action.decrementTen: game.adjustLife(for: player, by: -10)
        case Action.reset:     game.resetLife(for: player)
        default: break
        }
    }
}
