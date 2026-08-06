// CompactLayout.swift — Tile layout: title, value and secondary line, no metadata footer.

public extension WidgetLayout {
    /// Tight: title + value + secondary line, no metadata footer.
    static let compact = Self(id: "compact") { content in
        var header: [WidgetView] = []
        if let title = content.title {
            header.append(.text(title, role: .title))
        }
        header.append(.spacer)
        if let accessory = content.accessoryText {
            header.append(.badge(accessory))
        }

        var children: [WidgetView] = [
            .stack(.horizontal, spacing: 8, header),
            .text(content.primaryText, role: .primary),
        ]
        if let secondary = content.secondaryText {
            children.append(.text(secondary, role: .secondary))
        }
        return .stack(.vertical, spacing: 4, children)
    }
}
