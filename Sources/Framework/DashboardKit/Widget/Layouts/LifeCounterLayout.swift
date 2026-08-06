// LifeCounterLayout.swift — Tile layout: tappable +/− flanking a big centred total.

public extension WidgetLayout {
    /// A big centred value with a tappable `+` above and `−` below, and the value
    /// itself tappable to reset. Built for `LifeCounterWidget`.
    ///
    /// Holding `+`/`−` moves by ten rather than one — the hold action is a separate
    /// name, so the widget decides the step size and the layout just says "this
    /// region also responds to a hold".
    ///
    /// The action names are the widget's own (`LifeCounterWidget.Action`), spelled
    /// literally here because layouts live in the framework and know nothing about
    /// any particular widget — the pairing is by string, which is what lets a
    /// layout stay pure data.
    static let lifeCounter = Self(id: "lifeCounter") { content in
        .stack(.vertical, spacing: 0, [
            .centered([.tappable(action: "life.increment", hold: "life.incrementTen", .text("+", role: .primary))]),
            .spacer,
            .centered([.tappable(action: "life.reset", hold: nil, .text(content.primaryText, role: .hero))]),
            .spacer,
            .centered([.tappable(action: "life.decrement", hold: "life.decrementTen", .text("−", role: .primary))]),
        ])
    }
}
