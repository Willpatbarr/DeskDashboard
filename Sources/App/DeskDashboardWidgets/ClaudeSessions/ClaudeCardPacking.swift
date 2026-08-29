// ClaudeCardPacking.swift — The one definition of how a session card's fields are packed.

import DashboardKit

/// The fields a session card carries, and the order they are packed in.
///
/// `WidgetContent` has no row type — a layout only ever sees title/primary/
/// secondary/accessory/metadata — so the board packs each card into a metadata
/// pair and the layout unpacks it. That packing is positional, which means the
/// writer (`ClaudeSessionsWidget.render`) and the reader
/// (`ClaudeSessionsLayout`) have to agree exactly; when they were written by
/// hand in two files, adding a field meant editing an index in both and
/// silently shifting every field after it if you got it wrong.
///
/// So the order lives HERE, once, and both sides go through it. Adding a field
/// is adding a case: the writer fills it by name and the reader asks for it by
/// name. Both files are in this module, so nothing is exported to make this
/// work.
enum ClaudeCardField: Int, CaseIterable {
    case age
    case sessionID
    case project
    case model
    case activity
    /// Why this session wants attention: the daemon's `blockedOn` value
    /// (`question` | `plan` | `changes-requested`), or `stalled`. The LAYOUT
    /// turns it into words and a colour — this is a kind, not a label.
    case flag
    /// `planning` | `implementing` | `review` | `done`, as the daemon derives it.
    case stage
    /// Pull request number, already formatted (`#2070`), or empty.
    case pullRequest
    /// `"1"` when GitHub says changes are requested — the one PR fact worth a
    /// colour of its own.
    case changesRequested
    /// The card's dot colour, resolved from the session's ATTENTION state
    /// rather than the column it sits in (see `ClaudeSession.attention`).
    /// Empty falls back to the column's own accent.
    case accentHex
    /// `"1"` on the one card whose tap menu is up. Appended rather than slotted
    /// in, because the packing is POSITIONAL — a new case belongs at the end
    /// where it cannot shift the fields either side of it.
    case menuOpen

    /// U+001F, the unit separator: never appears in any of these values.
    static let separator = "\u{1F}"

    /// Packs a card, filling unset fields with empty strings so the field count
    /// is always the same.
    static func pack(_ values: [ClaudeCardField: String]) -> String {
        allCases.map { values[$0] ?? "" }.joined(separator: separator)
    }
}

/// One packed card, read back by field name.
struct ClaudeCard {
    private let values: [String]

    init(_ packed: String) {
        values = packed
            .split(separator: "\u{1F}", omittingEmptySubsequences: false)
            .map(String.init)
    }

    subscript(field: ClaudeCardField) -> String {
        values.indices.contains(field.rawValue) ? values[field.rawValue] : ""
    }
}

/// The fields of the long-press DETAIL panel, packed the same positional way as
/// a card and travelling in the same metadata list — see
/// `ClaudeSessionsWidget.render` for how the layout tells the two apart.
///
/// Overlaps a card's fields on purpose rather than reusing `ClaudeCardField`:
/// the values here are the UNTRUNCATED ones (a card's title and activity are cut
/// to the column width, which is exactly what the panel exists to undo), and the
/// panel carries facts no card has room for.
enum ClaudeDetailField: Int, CaseIterable {
    case sessionID
    /// Full title — not `rowTitle`'s truncation, and with no `⚙n` suffix.
    case title
    /// Full last-activity line.
    case activity
    case project
    /// `owner/name`, when the session has a PR.
    case repo
    case branch
    /// The branch the work merges into.
    case base
    /// `"1"` when the session runs in a git worktree.
    case worktree
    case stage
    /// Same kind vocabulary as `ClaudeCardField.flag`.
    case flag
    /// Already formatted (`#2070`), or empty.
    case pullRequest
    case prState
    case prReviewDecision
    case prIsDraft
    case model
    case effort
    case permissionMode
    case planName
    case age
    /// The session's attention colour, for the panel's accent bar.
    case accentHex
    /// The label of the column this session sits in — the panel's title reads
    /// `Session name - COLUMN`. Appended rather than slotted in beside `stage`:
    /// the packing is POSITIONAL, so a new case belongs at the end where it
    /// cannot shift the fields either side of it.
    case columnLabel
    /// That column's own accent, so the label above is tinted like the column
    /// header it names.
    case columnColorHex

    static func pack(_ values: [ClaudeDetailField: String]) -> String {
        allCases.map { values[$0] ?? "" }.joined(separator: ClaudeCardField.separator)
    }
}

/// One packed detail block, read back by field name.
struct ClaudeDetail {
    private let values: [String]

    init(_ packed: String) {
        values = packed
            .split(separator: "\u{1F}", omittingEmptySubsequences: false)
            .map(String.init)
    }

    subscript(field: ClaudeDetailField) -> String {
        values.indices.contains(field.rawValue) ? values[field.rawValue] : ""
    }
}

/// One subagent row inside the detail panel. Its own record because a session
/// carries a variable number of them, one metadata pair each.
enum ClaudeAgentField: Int, CaseIterable {
    case label
    case agentType
    case model
    /// `"1"` while the agent is still in flight.
    case running
    /// Duration in seconds, already computed by the daemon, or empty.
    case seconds
    case failed

    static func pack(_ values: [ClaudeAgentField: String]) -> String {
        allCases.map { values[$0] ?? "" }.joined(separator: ClaudeCardField.separator)
    }
}

/// One packed agent row, read back by field name.
struct ClaudeAgentRow {
    private let values: [String]

    init(_ packed: String) {
        values = packed
            .split(separator: "\u{1F}", omittingEmptySubsequences: false)
            .map(String.init)
    }

    subscript(field: ClaudeAgentField) -> String {
        values.indices.contains(field.rawValue) ? values[field.rawValue] : ""
    }
}

/// The same idea for a column's header record. Columns are ⟨RS⟩-separated from
/// each other, their fields ⟨US⟩-separated like a card's.
enum ClaudeColumnField: Int, CaseIterable {
    case label
    case count
    case colorHex
    /// How many cards follow for this column — the layout walks the flat
    /// metadata list by these offsets, since columns are variable length.
    case rendered

    /// U+001E, the record separator.
    static let columnSeparator = "\u{1E}"

    static func pack(_ values: [ClaudeColumnField: String]) -> String {
        allCases.map { values[$0] ?? "" }.joined(separator: ClaudeCardField.separator)
    }
}

/// One packed column header, read back by field name.
struct ClaudeColumnHeader {
    private let values: [String]

    init(_ packed: String) {
        values = packed
            .split(separator: "\u{1F}", omittingEmptySubsequences: false)
            .map(String.init)
    }

    subscript(field: ClaudeColumnField) -> String {
        values.indices.contains(field.rawValue) ? values[field.rawValue] : ""
    }

    /// Every column header in a `secondaryText`.
    static func all(in packed: String) -> [ClaudeColumnHeader] {
        packed
            .split(separator: "\u{1E}", omittingEmptySubsequences: false)
            .map { ClaudeColumnHeader(String($0)) }
    }
}
