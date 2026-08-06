// MediaCompactLayout.swift — Tile layout: now-playing at supporting size (superseded).

public extension WidgetLayout {
    /// Media/now-playing: title label, the primary value at *supporting* size
    /// (not the big primary role) so long song titles fit, a caption subline,
    /// and any badge. Good for the Music tile.
    static let mediaCompact = Self(id: "mediaCompact") { content in
        var children: [WidgetView] = []
        if let title = content.title {
            children.append(.text(title, role: .title))
        }
        // Primary at the smaller `.secondary` size so a long song title fits.
        children.append(.text(content.primaryText, role: .secondary))
        if let secondary = content.secondaryText {
            children.append(.text(secondary, role: .caption))
        }
        if let accessory = content.accessoryText {
            children.append(.badge(accessory))
        }
        return .stack(.vertical, spacing: 4, children)
    }
}
