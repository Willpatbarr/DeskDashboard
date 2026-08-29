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
    /// A tap focuses the session on the Mac; a LONG PRESS opens the detail
    /// panel over the board — the card is deliberately terse, and the panel is
    /// where its truncations are undone.
    ///
    /// **On the fixed-shape rule** (`lifeCounter`'s note): that requirement
    /// exists because a node inserted mid-press makes GTK cancel the gesture on
    /// the widget being held, so a HOLD's auto-repeat never receives its release
    /// and runs away. These cards DO hold now — but with `.once`, which starts
    /// no repeater (see `HoldAction`), so there is nothing a missing release can
    /// strand. That is the property `ClaudeSessionsWidgetTests` pins, so this
    /// reasoning cannot silently stop being true; the worst case here is still
    /// only a tap lost to a re-render.
    ///
    /// Data arrives packed (see `ClaudeSessionsWidget`): metadata holds every
    /// card in column order, `secondaryText` holds
    /// `label⟨US⟩count⟨US⟩color⟨US⟩rendered` per column (⟨RS⟩-joined), and
    /// `rendered` is how the walk below finds each column's slice. Anything in
    /// metadata PAST the cards is the open session's detail panel.
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
                    action: "claude.focus.\(sessionID)",
                    // `.once`, never `.repeating`: opening the panel rebuilds
                    // the widget under the finger, GTK then stops delivering
                    // `released`, and a repeat would re-open what you just
                    // dismissed for the next nine seconds.
                    hold: .once("claude.detail.\(sessionID)"),
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
        let board = WidgetView.columns(spacing: 10, columns)

        // Everything past the cards is the open session's panel: the detail
        // block, then one entry per subagent. `running` is already the total
        // card count, so this needs no sentinel.
        guard content.metadata.count > running else { return board }
        let detail = ClaudeDetail(content.metadata[running].value)
        let agents = content.metadata[(running + 1)...].map { ClaudeAgentRow($0.value) }

        /// One `LABEL  value` line, dropped entirely when there is no value —
        /// a panel of empty labels reads as broken data rather than as a
        /// session that simply has no PR.
        func fact(_ label: String, _ value: String, color: ColorToken = textBright) -> [WidgetView] {
            guard !value.isEmpty else { return [] }
            return [.stack(.horizontal, spacing: 6, [
                .coloredText(label.uppercased(), role: .caption, color: textDim),
                .coloredText(value, role: .caption, color: color),
                .spacer,
            ])]
        }

        let prLine = [detail[.pullRequest], detail[.prState].lowercased(),
                      detail[.prIsDraft] == "1" ? "draft" : "",
                      detail[.prReviewDecision].lowercased().replacingOccurrences(of: "_", with: " ")]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let runtime = [detail[.model], detail[.effort], detail[.permissionMode]]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let (detailFlagText, detailFlagHex) = flagStyle(detail[.flag])
        let accentBar = detail[.accentHex].isEmpty
            ? ColorToken.hex("#6b7280") : ColorToken.hex(detail[.accentHex])

        // The column this session sits in, tinted like its header on the board.
        let columnTint = detail[.columnColorHex].isEmpty
            ? textDim : ColorToken.hex(detail[.columnColorHex])
        // No leading dash: it existed only to join this to the title when the
        // two shared a line, and the column has had its own line since.
        let columnLabel = detail[.columnLabel].uppercased()

        // LEFT: what the session IS. Panel type is `.secondary` (body size), not
        // the cards' `.caption`: this is a focused view of one session, not a
        // column of twelve, so it gets room to be read from across the desk.
        let detailsCard = WidgetView.card(
            CardStyle(fill: columnWell, border: line, accent: accentBar,
                      accentWidth: 4, cornerRadius: 12, padding: 10),
            .stack(.vertical, spacing: 2, [
                // The title gets the card's FULL width — nothing shares its row.
                // Sharing it with the column label, the age and the close button
                // left it about half this wide, and a label wraps inside its own
                // share, so a long title ellipsized away — the one thing this
                // panel exists to prevent.
                .coloredText(detail[.title], role: .secondary, color: textBright),
                // Column and age sit under it as a subtitle rather than beside
                // it, so neither one can squeeze the title.
                .stack(.horizontal, spacing: 8, [
                    .coloredText(columnLabel, role: .caption, color: columnTint),
                    .coloredText(detail[.age], role: .caption, color: textDim),
                    .spacer,
                ]),
                .divider,
                .scroll(fade: columnWell, .stack(.vertical, spacing: 3,
                    fact("", detail[.activity])
                        + (detailFlagText.isEmpty ? [] : fact("", detailFlagText, color: detailFlagHex))
                        + fact("repo", [detail[.repo], detail[.project]]
                            .first { !$0.isEmpty } ?? "")
                        + fact("branch", [detail[.branch],
                                          detail[.base].isEmpty ? "" : "→ \(detail[.base])",
                                          detail[.worktree] == "1" ? "· worktree" : ""]
                            .filter { !$0.isEmpty }.joined(separator: " "))
                        + fact("pr", prLine, color: prColor)
                        + fact("stage", detail[.stage])
                        + fact("plan", detail[.planName], color: planColor)
                        + fact("model", runtime)
                )),
            ]))

        // RIGHT: what it SPAWNED. Same card shape as a session card, so an agent
        // reads as the same kind of thing one column over.
        let agentCards: [WidgetView] = agents.map { agent in
            // NOT `running` — that name belongs to the card count above, and
            // this closure would shadow it.
            let inFlight = agent[.running] == "1"
            let failed = agent[.failed] == "1"
            let seconds = Int(agent[.seconds])
            // Green while in flight, dim once done, red if it errored — the same
            // three-way reading the cards use. It is the card's accent bar AND
            // the type's tint, so state is carried by the same treatment the
            // session cards use rather than by a glyph of its own.
            let color: ColorToken = failed
                ? changesColor : (inFlight ? ColorToken.hex("#4ade80") : textDim)
            let kind = agent[.agentType]
            // State also stated in WORDS, not colour alone — a dim card and a
            // red one are the same card to anyone reading it at a glance.
            let trailing = [
                inFlight ? "running" : (failed ? "failed" : ""),
                seconds.map(ClaudeSessionsWidgetModel.ageLabel) ?? "",
            ].filter { !$0.isEmpty }.joined(separator: " · ")
            return .card(CardStyle(fill: cardFace, border: line, accent: color,
                                   accentWidth: 4, cornerRadius: 12, padding: 8),
                         .stack(.horizontal, spacing: 6, [
                             .coloredText(agent[.label], role: .secondary, color: textBright),
                             .coloredText(kind.isEmpty ? "" : "— \(kind)",
                                          role: .secondary, color: color),
                             .spacer,
                             .coloredText(trailing, role: .caption, color: textDim),
                         ]))
        }

        let subagents = WidgetView.stack(.vertical, spacing: 6, [
            .card(CardStyle(fill: columnWell, border: line,
                            cornerRadius: 12, padding: 10),
                  .stack(.horizontal, spacing: 8, [
                      .coloredText("Subagents", role: .secondary, color: textBright),
                      .spacer,
                      .coloredText(agents.isEmpty ? "" : "\(agents.count)",
                                   role: .caption, color: textDim),
                  ])),
            // The column stays even with nothing in it, saying so. Collapsing to
            // a full-width panel would make the layout jump between sessions,
            // and most sessions spawn no agents at all — an empty half-panel with
            // no explanation reads as a bug.
            //
            // The empty state is a CARD, not a bare line. Measured on the panel:
            // loose text here floated over the dimmed board behind and collided
            // with it, because nothing in this column was painting a surface.
            .scroll(fade: columnWell, .stack(.vertical, spacing: 6,
                agentCards.isEmpty
                    ? [.card(CardStyle(fill: cardFace, border: line,
                                       cornerRadius: 12, padding: 8),
                             .stack(.horizontal, spacing: 6, [
                                 .coloredText("none this session",
                                              role: .caption, color: textDim),
                                 .spacer,
                             ]))]
                    : agentCards)),
        ])

        // Just the two cards, splitting the width evenly. `.columns`, because
        // greedy siblings do NOT split leftover width evenly on the GTK backend.
        //
        // No close button here, and no full-bleed dismiss tappable either. Both
        // belong to the MODAL, not to this widget, and the renderer draws them
        // around the panel from `.layered`'s `dismiss` action:
        //
        //  - The button was tried here first, beside the columns in a
        //    `.stack(.horizontal)`. It cannot work: `.columns` is a
        //    GeometryReader, which has no intrinsic width, so a stack starves it
        //    — measured, both cards collapsed to slivers.
        //  - The full-bleed tappable sat under the agents list and ate the first
        //    touch of every scroll gesture.
        let panel = WidgetView.columns(spacing: 10, [detailsCard, subagents])

        // Built ONLY here, inside the guard — an overlay is a real widget on the
        // GTK backend and swallows every tap under it, so a layer that existed
        // while nothing was open would make the whole board untappable.
        // Nearly opaque, and that is measured rather than taste. Lightening it
        // to ~72% so the board "showed through" looked right on the Mac and bad
        // on the panel: the board behind is dense text, and at that alpha the
        // session titles underneath stayed legible enough to be read THROUGH the
        // panel's own words. The inset margin is what says "this is a layer" —
        // the scrim's job is only to kill the board, not to display it.
        return .layered(
            board,
            scrimHex: "#0b0d10ed",
            dismiss: "claude.detail.close",
            over: panel
        )
    }
}
