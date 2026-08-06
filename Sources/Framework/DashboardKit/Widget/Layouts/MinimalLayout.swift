// MinimalLayout.swift — Tile layout: the value alone.

public extension WidgetLayout {
    /// Just the value, nothing else.
    static let minimal = Self(id: "minimal") { content in
        .stack(.vertical, spacing: 0, [.text(content.primaryText, role: .hero)])
    }
}
