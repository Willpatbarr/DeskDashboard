// CenteredValueLayout.swift — Tile layout: top-left title, value centred horizontally.

public extension WidgetLayout {
    /// Title parked at the top-left, with the value (and its supporting line)
    /// centred **horizontally** and top-aligned vertically — the value container
    /// starts right below the title, exactly where every other layout puts its
    /// value, so a row of tiles lines up. For a tile whose value is the
    /// centrepiece, like the board's clock.
    static let centeredValue = Self(id: "centeredValue") { content in
        var children: [WidgetView] = []
        if let title = content.title {
            children.append(.text(title, role: .title))
        }

        // Both lines in one `.centered` group so they share a centre line, and the
        // group sits directly under the title with only a *trailing* spacer: that
        // top-aligns it with the values in neighbouring tiles instead of floating it
        // in the middle of its own tile.
        var value: [WidgetView] = [.text(content.primaryText, role: .display)]
        if let secondary = content.secondaryText {
            value.append(.text(secondary, role: .subtitle))
        }
        children.append(.centered(value))
        children.append(.spacer)

        return .stack(.vertical, spacing: 2, children)
    }
}
