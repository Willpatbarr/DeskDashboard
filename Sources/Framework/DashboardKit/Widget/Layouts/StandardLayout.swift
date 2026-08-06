// StandardLayout.swift — Tile layout: title/badge row, primary value, secondary line, metadata footer.

public extension WidgetLayout {
    /// Title + badge row, primary value, secondary line, metadata footer.
    /// The default; matches the original tile arrangement.
    static let standard = Self(id: "standard") { content in
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
        children.append(.spacer)
        if let metadata = WidgetLayout.metadataLine(content) {
            children.append(.text(metadata, role: .caption))
        }

        return .stack(.vertical, spacing: 6, children)
    }
}
