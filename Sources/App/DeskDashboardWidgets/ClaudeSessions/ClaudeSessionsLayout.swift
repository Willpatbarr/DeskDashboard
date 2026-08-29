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

        // STRUCTURE follows the theme — wells, cards, rules, body text — so
        // this board wears whatever the board is wearing. `HTMLerTheme` is the
        // palette these were originally authored in, kept verbatim there.
        let columnWell = ColorToken.surface
        let cardFace = ColorToken.surfaceRaised
        let textBright = ColorToken.text
        let textDim = ColorToken.muted
        let line = ColorToken.border

        // MEANING does not. These stay literal on purpose: they are the same
        // colours the web board uses to SAY something, and a session that
        // wants you must not stop looking urgent because the theme changed.
        let flagColor = ColorToken.hex("#fbbf24")
        let planColor = ColorToken.hex("#c4b5fd")
        let changesColor = ColorToken.hex("#f87171")
        // Blue whatever the review says — "there is a PR here" is the fact the
        // number carries; the flag line below says if it needs you, in red.
        let prColor = ColorToken.hex("#60a5fa")

        /// Blocked reasons and their words, matching the web board's `.flag`
        /// rules. A blocked card says what it is blocked ON; a stalled one is
        /// only a suspicion, so it keeps its question mark.
        func flagStyle(_ kind: String) -> (String, ColorToken) {
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
            // The column's own accent, pushed by the daemon — data, not theme.
            let accent = header[.colorHex].isEmpty
                ? textDim : ColorToken.hex(header[.colorHex])
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
                let dotHex = card[.accentHex].isEmpty
                    ? accent : ColorToken.hex(card[.accentHex])

                return .tappable(
                    action: "claude.focus.\(sessionID)", hold: nil,
                    .card(CardStyle(fill: cardFace, border: line, accent: dotHex,
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
                                               role: .caption, color: textBright),
                                  .spacer,
                                  .coloredText(card[.age], role: .caption, color: textDim),
                              ]),
                              .stack(.horizontal, spacing: 6, [
                                  // No stage token: the COLUMN names the stage,
                                  // so repeating it on every card is noise.
                                  .coloredText(meta, role: .caption, color: textDim),
                                  .spacer,
                                  .coloredText(card[.pullRequest], role: .caption, color: prColor),
                              ]),
                              .stack(.horizontal, spacing: 6, [
                                  .coloredText(flagText, role: .caption, color: flagHex),
                                  .coloredText(flagText.isEmpty ? card[.activity] : "",
                                               role: .caption, color: textDim),
                                  .spacer,
                              ]),
                          ]))
                )
            }

            return .card(CardStyle(fill: columnWell, border: line,
                                   cornerRadius: 12, padding: 6),
                         .stack(.vertical, spacing: 4, [
                             .stack(.horizontal, spacing: 8, [
                                 .coloredText(label.uppercased(), role: .caption, color: accent),
                                 .coloredText(stale, role: .caption, color: flagColor),
                                 .spacer,
                                 .coloredText(count, role: .caption, color: textDim),
                             ]),
                             // The cards scroll; the header above stays put.
                             // Clipped cards fade into the well at each edge.
                             .scroll(fade: columnWell, .stack(.vertical, spacing: 4, slots)),
                         ]))
        }

        // No tile-level header row: the columns ARE the widget (the counts live
        // in their headers, the staleness flag in the first one), and every
        // vertical point goes to the cards.
        return .columns(spacing: 10, columns)
    }
}
