// ClaudeSessionsLayout.swift — Tile layout: the web dashboard's kanban, scrollable per column.

import DashboardKit

public extension WidgetLayout {
    /// The Claude session kanban, mirroring the AgentManager web dashboard:
    /// column wells, dark session cards with the column's accent dot, dim meta
    /// line, activity line. Colours are the web board's own hex values (plus
    /// the accents the daemon pushes per column) — this tile deliberately does
    /// NOT follow the theme, which is why it leans on `.card`/`.coloredText`.
    ///
    /// Each column's cards sit in a `.scroll`, so a column with more sessions
    /// than fit is scrolled rather than clipped or overflowing. That is also
    /// why the columns are VARIABLE length now: with a scroll region there is
    /// nothing to be gained from padding them to a fixed count, and blank cards
    /// would only add dead space to scroll through.
    ///
    /// **On the fixed-shape rule** (`lifeCounter`'s note): that requirement
    /// exists because a node inserted mid-press makes GTK cancel the gesture on
    /// the widget being held, so a HOLD's auto-repeat never receives its
    /// release and runs away. These cards are tap-only (`hold: nil`), so the
    /// failure it guards against cannot occur — the worst case here is a tap
    /// lost to a re-render, and `ClaudeSessionsWidgetTests` pins the no-hold
    /// property so this reasoning cannot silently stop being true.
    ///
    /// Data arrives packed (see `ClaudeSessionsWidget`): metadata holds every
    /// card in column order, `secondaryText` holds
    /// `label⟨US⟩count⟨US⟩color⟨US⟩rendered` per column (⟨RS⟩-joined), and
    /// `rendered` is how the walk below finds each column's slice.
    static let claudeSessions = Self(id: "claudeSessions") { content in

        // The web dashboard's palette (public/index.html :root), verbatim.
        let columnWell = "#15181d"
        let cardFace = "#1d2229"
        let textBright = "#e8eaed"
        let textDim = "#9aa0a8"
        let flagColor = "#fbbf24"
        let planColor = "#c4b5fd"
        let changesColor = "#f87171"
        // PR numbers are blue whatever the review says — "there is a PR here"
        // is the fact the number carries; the flag line below says if it needs
        // you, in red.
        let prColor = "#60a5fa"
        let line = "#2a2f37"

        /// Blocked reasons and their words, matching the web board's `.flag`
        /// rules. A blocked card says what it is blocked ON; a stalled one is
        /// only a suspicion, so it keeps its question mark.
        func flagStyle(_ kind: String) -> (String, String) {
            switch kind {
            case "question": ("question waiting", flagColor)
            case "plan": ("plan approval", planColor)
            case "changes-requested": ("changes requested", changesColor)
            case "stalled": ("stalled?", changesColor)
            default: ("", textDim)
            }
        }

        // However many the daemon pushed — the board's columns are config, not
        // a constant, so a fourth one needs no Pi rebuild.
        let headers = ClaudeColumnHeader.all(in: content.secondaryText ?? "")
            .filter { !$0[.label].isEmpty }
        let columnCount = headers.count

        func rendered(_ columnIndex: Int) -> Int {
            guard headers.indices.contains(columnIndex) else { return 0 }
            return Int(headers[columnIndex][.rendered]) ?? 0
        }

        // Where each column's cards start in the flat metadata list.
        var offsets: [Int] = []
        var running = 0
        for index in 0 ..< columnCount {
            offsets.append(running)
            running += rendered(index)
        }

        let columns: [WidgetView] = (0 ..< columnCount).map { columnIndex in
            let header = headers.indices.contains(columnIndex)
                ? headers[columnIndex] : ClaudeColumnHeader("")
            let label = header[.label]
            let count = header[.count]
            let accent = header[.colorHex].isEmpty ? textDim : header[.colorHex]
            let start = offsets[columnIndex]

            // The staleness flag lives in the first column's header now that
            // the tile has no counts row of its own.
            let stale = columnIndex == 0 ? (content.accessoryText ?? "") : ""

            let slots: [WidgetView] = (0 ..< rendered(columnIndex)).compactMap { slotIndex in
                let flatIndex = start + slotIndex
                guard flatIndex < content.metadata.count else { return nil }
                let card = ClaudeCard(content.metadata[flatIndex].value)
                let sessionID = card[.sessionID]
                let meta = [card[.project], card[.model]].filter { !$0.isEmpty }
                    .joined(separator: " · ")
                let (flagText, flagHex) = flagStyle(card[.flag])
                // The BAR says what state the session is in — with stage-based
                // columns that is a different fact from which column it's in.
                let dotHex = card[.accentHex].isEmpty ? accent : card[.accentHex]

                return .tappable(
                    action: "claude.focus.\(sessionID)", hold: nil,
                    .card(CardStyle(hex: cardFace, borderHex: line, accentHex: dotHex,
                                    cornerRadius: 8, padding: 5),
                          .stack(.vertical, spacing: 2, [
                              .stack(.horizontal, spacing: 6, [
                                  // Attention state is the bar down this card's
                                  // leading edge (the web board's treatment), so
                                  // no glyph for it here. Everything in a card is
                                  // caption-sized: `.secondary` maps to bodySize
                                  // (24 → 36px on the panel), far too heavy for
                                  // a card this size.
                                  .coloredText(content.metadata[flatIndex].label,
                                               role: .caption, hex: textBright),
                                  .spacer,
                                  .coloredText(card[.age], role: .caption, hex: textDim),
                              ]),
                              .stack(.horizontal, spacing: 6, [
                                  // No stage token: the COLUMN names the stage,
                                  // so repeating it on every card is noise.
                                  .coloredText(meta, role: .caption, hex: textDim),
                                  .spacer,
                                  .coloredText(card[.pullRequest], role: .caption, hex: prColor),
                              ]),
                              .stack(.horizontal, spacing: 6, [
                                  .coloredText(flagText, role: .caption, hex: flagHex),
                                  .coloredText(flagText.isEmpty ? card[.activity] : "",
                                               role: .caption, hex: textDim),
                                  .spacer,
                              ]),
                          ]))
                )
            }

            return .card(CardStyle(hex: columnWell, borderHex: line,
                                   cornerRadius: 12, padding: 6),
                         .stack(.vertical, spacing: 4, [
                             .stack(.horizontal, spacing: 8, [
                                 .coloredText(label.uppercased(), role: .caption, hex: accent),
                                 .coloredText(stale, role: .caption, hex: flagColor),
                                 .spacer,
                                 .coloredText(count, role: .caption, hex: textDim),
                             ]),
                             // The cards scroll; the header above stays put.
                             // Clipped cards fade into the well at each edge.
                             .scroll(fadeHex: columnWell, .stack(.vertical, spacing: 4, slots)),
                         ]))
        }

        // No tile-level header row: the columns ARE the widget (the counts live
        // in their headers, the staleness flag in the first one), and every
        // vertical point goes to the cards.
        return .columns(spacing: 10, columns)
    }
}
