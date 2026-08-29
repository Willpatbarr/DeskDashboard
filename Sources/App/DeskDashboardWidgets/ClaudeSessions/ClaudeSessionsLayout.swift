// ClaudeSessionsLayout.swift — Tile layout: the web dashboard's kanban, drawn in its own colors.

import DashboardKit

public extension WidgetLayout {
    /// The Claude session kanban, mirroring the AgentManager web dashboard:
    /// column wells, dark session cards with the column's accent dot, dim meta
    /// line, activity line. Colours are the web board's own hex values (plus
    /// the accents the daemon pushes per column) — this tile deliberately does
    /// NOT follow the theme, which is why it leans on `.card`/`.coloredText`.
    ///
    /// **Every node is unconditional; only the STRINGS vary** — the GTK rule
    /// from `lifeCounter`. The grid shape is fixed by the model (columnCount ×
    /// slotCount, blanks padded); blank slots render as cards in the column
    /// well's own colour, i.e. invisibly, and raise the inert `claude.none`.
    ///
    /// Data arrives packed (see `ClaudeSessionsWidget`): metadata slots hold
    /// `title` + `age⟨US⟩id⟨US⟩project⟨US⟩model⟨US⟩activity⟨US⟩flag`;
    /// `secondaryText` holds `label⟨US⟩count⟨US⟩color` per column, ⟨RS⟩-joined.
    static let claudeSessions = Self(id: "claudeSessions") { content in
        let columnCount = 3
        let slotCount = 3

        // The web dashboard's palette (public/index.html :root), verbatim.
        let columnWell = "#15181d"
        let cardFace = "#1d2229"
        let textBright = "#e8eaed"
        let textDim = "#9aa0a8"
        let flagColor = "#fbbf24"
        let line = "#2a2f37"

        let headers = (content.secondaryText ?? "")
            .split(separator: "\u{1E}", omittingEmptySubsequences: false)
            .map { record in
                record.split(separator: "\u{1F}", omittingEmptySubsequences: false)
                    .map(String.init)
            }

        let columns: [WidgetView] = (0 ..< columnCount).map { columnIndex in
            let header = columnIndex < headers.count ? headers[columnIndex] : []
            let label = header.indices.contains(0) ? header[0] : ""
            let count = header.indices.contains(1) ? header[1] : ""
            let accent = header.indices.contains(2) && !header[2].isEmpty
                ? header[2] : textDim

            // The staleness flag lives in the first column's header now that
            // the tile has no counts row of its own.
            let stale = columnIndex == 0 ? (content.accessoryText ?? "") : ""

            let slots: [WidgetView] = (0 ..< slotCount).map { slotIndex in
                let flatIndex = columnIndex * slotCount + slotIndex
                let entry = flatIndex < content.metadata.count
                    ? content.metadata[flatIndex]
                    : WidgetContentMetadata(label: "", value: "")
                let fields = entry.value
                    .split(separator: "\u{1F}", omittingEmptySubsequences: false)
                    .map(String.init)
                let age = fields.indices.contains(0) ? fields[0] : ""
                let sessionID = fields.indices.contains(1) ? fields[1] : ""
                let project = fields.indices.contains(2) ? fields[2] : ""
                let model = fields.indices.contains(3) ? fields[3] : ""
                let activity = fields.indices.contains(4) ? fields[4] : ""
                let flag = fields.indices.contains(5) ? fields[5] : ""

                let action = sessionID.isEmpty ? "claude.none" : "claude.focus.\(sessionID)"
                // Blank slots wear the well's own colour — present in the tree
                // (the GTK rule) but invisible on the board.
                let face = sessionID.isEmpty ? columnWell : cardFace
                let meta = [project, model].filter { !$0.isEmpty }
                    .joined(separator: " · ")

                return .tappable(
                    action: action, hold: nil,
                    .card(hex: face, borderHex: sessionID.isEmpty ? nil : line, cornerRadius: 8, padding: 5, .stack(.vertical, spacing: 2, [
                        .stack(.horizontal, spacing: 6, [
                            // The column accent, standing in for the web card's
                            // coloured left border. Everything in a card is
                            // caption-sized: `.secondary` maps to bodySize (24
                            // → 36px on the panel), and three body-height cards
                            // per column overflow the strip — measured, twice.
                            .coloredText(sessionID.isEmpty ? "" : "●", role: .caption, hex: accent),
                            .coloredText(entry.label, role: .caption, hex: textBright),
                            .spacer,
                            .coloredText(age, role: .caption, hex: textDim),
                        ]),
                        .stack(.horizontal, spacing: 6, [
                            .coloredText(meta, role: .caption, hex: textDim),
                            .coloredText(flag, role: .caption, hex: flagColor),
                            .spacer,
                        ]),
                        .coloredText(activity, role: .caption, hex: textDim),
                    ]))
                )
            }

            return .card(hex: columnWell, borderHex: line, cornerRadius: 12, padding: 6, .stack(.vertical, spacing: 4, [
                .stack(.horizontal, spacing: 8, [
                    .coloredText(label.uppercased(), role: .caption, hex: accent),
                    .coloredText(stale, role: .caption, hex: flagColor),
                    .spacer,
                    .coloredText(count, role: .caption, hex: textDim),
                ]),
            ] + slots + [.spacer]))
        }

        // No tile-level header row: the columns ARE the widget (the counts live
        // in their headers, the staleness flag in the first one), and every
        // vertical point goes to the cards.
        return .columns(spacing: 10, columns)
    }
}
