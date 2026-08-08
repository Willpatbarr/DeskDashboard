// RuledLayout.swift — Tile layout: label over a rule, value, and a footer under a second rule.

public extension WidgetLayout {
    /// `standard`, ruled: label, hairline, value, supporting line — then the
    /// footer pinned to the bottom under a second hairline.
    ///
    /// **Every node is unconditional, absent text drawn as an empty string.** The
    /// footer rule is therefore present on a tile with nothing to put under it,
    /// which is the point: all four tiles on a board share one internal skeleton,
    /// so their labels, values and rules line up across the row no matter what
    /// each widget happens to be reporting. It also keeps the node tree constant,
    /// which on GTK is a correctness property rather than a tidiness one — see
    /// `lifeCounter` and §3 of the handoff for what adding a node mid-press does
    /// to a gesture.
    ///
    /// The `.spacer` between the supporting line and the footer rule is what
    /// pins the footer down; everything above it sits at the top of the tile.
    static let ruled = Self(id: "ruled") { content in
        .stack(.vertical, spacing: 6, [
            .text(content.title ?? "", role: .title),
            .divider,
            .text(content.primaryText, role: .primary),
            .text(content.secondaryText ?? "", role: .secondary),
            .spacer,
            .divider,
            .text(WidgetLayout.metadataLine(content) ?? "", role: .caption),
        ])
    }
}
