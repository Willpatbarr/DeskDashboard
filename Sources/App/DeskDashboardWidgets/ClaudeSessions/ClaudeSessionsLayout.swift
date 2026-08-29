// ClaudeSessionsLayout.swift — Tile layout: a kanban of session columns, every slot tappable.

import DashboardKit

public extension WidgetLayout {
    /// The Claude session kanban: title + counts line across the top, then the
    /// columns side by side — each a header, a hairline, and its session slots
    /// (title left, age right).
    ///
    /// **Every node is unconditional; only the STRINGS vary** — the GTK
    /// correctness rule from `lifeCounter`. The grid shape is fixed by
    /// `ClaudeSessionsWidgetModel` (columnCount × slotCount, blanks padded), so
    /// the tree never changes when sessions come and go. Blank slots raise the
    /// inert `claude.none` action.
    ///
    /// Grid data arrives packed (see `ClaudeSessionsWidget`): metadata holds the
    /// slots column-major, `secondaryText` holds the ⟨US⟩-joined column headers.
    /// The action names are `ClaudeSessionsWidget`'s vocabulary, reconstructed
    /// here by string — the same by-string pairing every interactive layout uses.
    static let claudeSessions = Self(id: "claudeSessions") { content in
        let columnCount = 3
        let slotCount = 5
        /// Minimum slot height — a comfortable finger band on the panel.
        let slotBand = 40.0

        let headers = content.secondaryText?
            .split(separator: "\u{1F}", omittingEmptySubsequences: false)
            .map(String.init) ?? []

        let columns: [WidgetView] = (0 ..< columnCount).map { columnIndex in
            let header = columnIndex < headers.count ? headers[columnIndex] : ""

            let slots: [WidgetView] = (0 ..< slotCount).map { slotIndex in
                let flatIndex = columnIndex * slotCount + slotIndex
                let entry = flatIndex < content.metadata.count
                    ? content.metadata[flatIndex]
                    : WidgetContentMetadata(label: "", value: "")
                let parts = entry.value.split(
                    separator: "\u{1F}", maxSplits: 1, omittingEmptySubsequences: false
                )
                let age = parts.indices.contains(0) ? String(parts[0]) : ""
                let sessionID = parts.indices.contains(1) ? String(parts[1]) : ""
                let action = sessionID.isEmpty ? "claude.none" : "claude.focus.\(sessionID)"

                return .tappable(
                    action: action, hold: nil,
                    .touchBand(slotBand, .stack(.horizontal, spacing: 8, [
                        .text(entry.label, role: .secondary),
                        .spacer,
                        .text(age, role: .caption),
                    ]))
                )
            }

            return .stack(.vertical, spacing: 4, [
                .text(header, role: .subtitle),
                .divider,
            ] + slots + [.spacer])
        }

        return .stack(.vertical, spacing: 6, [
            // Title, the cross-column counts line, and the staleness flag ("" when
            // fresh — the node stays) share the top row.
            .stack(.horizontal, spacing: 12, [
                .text(content.title ?? "", role: .title),
                .text(content.primaryText, role: .caption),
                .spacer,
                .text(content.accessoryText ?? "", role: .caption),
            ]),
            .divider,
            .stack(.horizontal, spacing: 24, columns),
        ])
    }
}
