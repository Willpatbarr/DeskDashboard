// MediaStackedLayout.swift — Tile layout: artist above a full-size song title that can wrap.

public extension WidgetLayout {
    /// Media/now-playing with the song title as the centrepiece: title label,
    /// then the artist line, then the song at full `.primary` size — last so it
    /// can wrap over multiple lines (that's how long titles fit here, instead of
    /// `mediaCompact`'s smaller type) without pushing the lines above around.
    /// Vertical spacing matches `.standard`, so the label→artist gap lines up
    /// with the temp tiles' label→value gap.
    static let mediaStacked = Self(id: "mediaStacked") { content in
        var body: [WidgetView] = []
        if let secondary = content.secondaryText {
            body.append(.text(secondary, role: .secondary))
        }
        body.append(.text(content.primaryText, role: .primary))
        if let accessory = content.accessoryText {
            body.append(.badge(accessory))
        }

        guard let title = content.title else {
            return .stack(.vertical, spacing: 6, body)
        }
        // The label→artist ink gap should read the same as `.standard`'s
        // label→value gap in the temp tiles, but spacing separates label BOXES,
        // and the artist's body-sized box leaves less air above its cap than the
        // heading-sized temp values do — measured 24px vs 33px on the panel at
        // spacing 6. The extra 6 units at this one join squares the inks up.
        // With no artist line, the primary sits right under the title exactly
        // like `.standard`, so plain spacing 6 already matches.
        let titleGap = content.secondaryText == nil ? 6.0 : 12.0
        return .stack(.vertical, spacing: titleGap, [
            .text(title, role: .title),
            .stack(.vertical, spacing: 6, body),
        ])
    }
}
