// TurnCounterLayout.swift — Tile layout: centred label, tappable count, optional reset.

public extension WidgetLayout {
    /// A centred label over a big tappable number, with a tappable reset badge
    /// below when the content supplies one. Built for `TurnCounterWidget`.
    ///
    /// The reset affordance is driven by `accessoryText` being present rather than
    /// by any count the layout inspects — layouts stay a pure mapping from content,
    /// so deciding *when* resetting makes sense belongs to the widget.
    static let turnCounter = Self(id: "turnCounter") { content in
        var children: [WidgetView] = []
        if let title = content.title {
            children.append(.centered([.text(title, role: .title)]))
        }
        // `fittedText`, not a fixed role: this tile's height depends on its board
        // (the MTG centre column shares it with a clock), and a display-size number
        // assumed ~233px of box — it overflowed the panel and took the reset badge
        // off-screen with it. Fitted text takes whatever the column granted.
        //
        // No spacers around it either: the fitted node is already greedy, and
        // spacers competing with it just squeeze the label and badge.
        children.append(.centered([
            .tappable(action: "turn.advance", hold: nil, .fittedText(content.primaryText)),
        ]))
        if let reset = content.accessoryText {
            children.append(.centered([.tappable(action: "turn.reset", hold: nil, .badge(reset))]))
        }
        return .stack(.vertical, spacing: 4, children)
    }
}
