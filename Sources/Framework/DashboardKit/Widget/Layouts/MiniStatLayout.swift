// MiniStatLayout.swift — Tile layout: label and value side by side, for a short strip of a tile.

public extension WidgetLayout {
    /// Label and value on ONE line, both small: the value takes the *supporting*
    /// (`.secondary`) size rather than any of the heading roles.
    ///
    /// For a tile that is WIDE but very SHORT — the bottom band of the focus board
    /// is ~66px on the Pi's strip, and measured there: `compact` (three lines) and
    /// `mediaCompact` (label + value + caption) overflow it outright, and even
    /// label-over-value ran a few pixels past the panel's bottom edge. Side by
    /// side, the tile is one line tall whatever the type scale does, which is the
    /// only version that can't clip. Anything else the widget would show — the
    /// artist, the humidity — is dropped rather than cut off.
    static let miniStat = miniStat(detail: false)

    /// `miniStat` with the supporting text (the artist, the humidity) joined to the
    /// value as ONE run: `supporting · value`, all at the value's size and colour.
    ///
    /// One `.text` node rather than two, because that's what makes them read as a
    /// single line rather than a value with a footnote — same role means same size
    /// and same colour, and the separator can't drift away from either side.
    /// Supporting text comes FIRST: for music that's `artist · song`, which is the
    /// way round you scan it.
    ///
    /// Only worth asking for on a tile that has the width for it — the focus
    /// board's music tile absorbs whatever the two hugging temp tiles leave, which
    /// is most of the board. On a narrow tile this run is what truncates, and it
    /// truncates from the song end.
    static func miniStat(detail: Bool) -> Self {
        Self(id: detail ? "miniStat.detail" : "miniStat") { content in
            var children: [WidgetView] = []
            if let title = content.title {
                children.append(.text(title, role: .title))
            }
            if detail, let secondary = content.secondaryText {
                children.append(.text("\(secondary) · \(content.primaryText)", role: .secondary))
            } else {
                children.append(.text(content.primaryText, role: .secondary))
            }
            // Trailing spacer, so the run sits together at the leading edge
            // instead of being spread across a very wide tile.
            children.append(.spacer)
            return .stack(.horizontal, spacing: 10, children)
        }
    }
}
