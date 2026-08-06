// BigNumberLayout.swift — Tile layout: small caption title above an oversized value.

public extension WidgetLayout {
    /// A big value with a small caption title above — good for a clock or a
    /// single temperature/number.
    static let bigNumber = Self(id: "bigNumber") { content in
        var children: [WidgetView] = []
        if let title = content.title {
            children.append(.text(title, role: .title))
        }
        children.append(.text(content.primaryText, role: .hero))
        if let secondary = content.secondaryText {
            children.append(.text(secondary, role: .secondary))
        }
        return .stack(.vertical, spacing: 2, children)
    }
}
