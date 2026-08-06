// CenteredValueLayout.swift — Tile layout: top-left title, value centred horizontally.

public extension WidgetLayout {
    /// Where `centeredValue` puts the supporting line, relative to the value.
    enum SubtitlePosition: Sendable {
        /// Under the value — the clock's date line.
        case below
        /// Over the value, between it and the title.
        case above
    }

    /// Title parked at the top-left, with the value (and its supporting line)
    /// centred **horizontally** and top-aligned vertically — the value container
    /// starts right below the title, exactly where every other layout puts its
    /// value, so a row of tiles lines up. For a tile whose value is the
    /// centrepiece, like the board's clock.
    static let centeredValue = centeredValue(subtitle: .below)

    /// `centeredValue` with the supporting line placed explicitly.
    ///
    /// The line is `content.secondaryText` either way — it appears once, on the
    /// side you pick, never both. It also goes *inside* the `.centered` group
    /// rather than the outer stack, so it shares the value's centre line; the
    /// outer stack is leading-aligned, and a subtitle appended there would sit
    /// against the left edge under the title.
    static func centeredValue(subtitle: SubtitlePosition) -> Self {
        Self(id: subtitle == .below ? "centeredValue" : "centeredValue.above") { content in
            var children: [WidgetView] = []
            if let title = content.title {
                children.append(.text(title, role: .title))
            }

            // Value and supporting line in one `.centered` group so they share a
            // centre line, and the group sits directly under the title with only a
            // *trailing* spacer: that top-aligns it with the values in neighbouring
            // tiles instead of floating it in the middle of its own tile.
            var value: [WidgetView] = []
            let supporting = content.secondaryText.map { WidgetView.text($0, role: .subtitle) }
            if subtitle == .above, let supporting {
                value.append(supporting)
            }
            value.append(.text(content.primaryText, role: .display))
            if subtitle == .below, let supporting {
                value.append(supporting)
            }

            children.append(.centered(value))
            children.append(.spacer)

            return .stack(.vertical, spacing: 2, children)
        }
    }
}
