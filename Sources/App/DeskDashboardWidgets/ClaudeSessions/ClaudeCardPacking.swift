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
