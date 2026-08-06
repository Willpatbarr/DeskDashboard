// FittedValueLayout.swift — Tile layout: centred label over a value scaled to fill the tile.

public extension WidgetLayout {
    /// The title centred at the top, then the value alone filling ALL remaining
    /// space, sized by the renderer to fit — the number scales with the widget.
    /// No secondary line, no metadata. For a temperature in a small tile.
    static let fittedValue = Self(id: "fittedValue") { content in
        var children: [WidgetView] = []
        if let title = content.title {
            children.append(.centered([.text(title, role: .title)]))
        }
        children.append(.fittedText(content.primaryText))
        return .stack(.vertical, spacing: 2, children)
    }
}
