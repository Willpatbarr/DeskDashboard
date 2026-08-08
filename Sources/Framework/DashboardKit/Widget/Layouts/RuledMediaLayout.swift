// RuledMediaLayout.swift — Tile layout: ruled media tile, artist above a full-size song title.

public extension WidgetLayout {
    /// `mediaStacked`, ruled: label, hairline, artist, then the song at full
    /// `.primary` size so a long title can wrap — with the same bottom rule and
    /// footer slot `ruled` uses, so a media tile lines up with its neighbours.
    ///
    /// The song comes last for the same reason it does in `mediaStacked`: it is
    /// the one line allowed to take several rows, and putting it last means
    /// wrapping pushes nothing around above it.
    ///
    /// Nodes are unconditional here too — see `ruled` for why that matters.
    static let ruledMedia = Self(id: "ruledMedia") { content in
        .stack(.vertical, spacing: 6, [
            .text(content.title ?? "", role: .title),
            .divider,
            // Artist and song share an inner stack at TIGHTER spacing than the
            // tile's. That is not a style choice: the song needs two lines' height
            // reserved (below), and at the outer spacing the two together came out
            // 1px taller than the band, which overflowed and shifted this tile's
            // rules off its neighbours'. Buying the pixel back from the gap between
            // artist and song leaves both rules where the other tiles put them,
            // where taking it from the outer spacing would have moved them.
            .stack(.vertical, spacing: 2, [
                .text(content.secondaryText ?? "", role: .secondary),
                // Without a reserved height the greedy spacer below takes the
                // remainder, the label is offered a single line, and a title too
                // wide for the tile ELLIPSIZES rather than wrapping — measured,
                // "Nothing playing" came out "Nothing playi…". `mediaStacked` can
                // put the song last and let it take what's left; this layout has a
                // footer pinned underneath, so the room has to be asked for.
                //
                // Measured on the panel, and the window is one pixel wide: 108 drew
                // a single line, 112 pushed the rules 2px out. Re-measure if the
                // heading size, the tile height or the spacings change.
                .region(minWidth: 0, minHeight: 112, .text(content.primaryText, role: .primary)),
            ]),
            .spacer,
            .divider,
            .text(WidgetLayout.metadataLine(content) ?? "", role: .caption),
        ])
    }
}
