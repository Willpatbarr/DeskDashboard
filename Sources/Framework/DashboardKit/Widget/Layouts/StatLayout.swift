// StatLayout.swift — Tile layout: oversized value with its label underneath, dashboard-stat style.

public extension WidgetLayout {
    /// A big value with the label *underneath* it (dashboard-stat style), plus
    /// any badge.
    static let stat = Self(id: "stat") { content in
        var children: [WidgetView] = [.text(content.primaryText, role: .hero)]
        if let title = content.title {
            children.append(.text(title, role: .caption))
        }
        if let accessory = content.accessoryText {
            children.append(.badge(accessory))
        }
        return .stack(.vertical, spacing: 2, children)
    }
}
