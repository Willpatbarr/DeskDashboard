// ContainerMode.swift — Header toggle state: whether board tiles draw their chrome.

/// Whether the tiles on a board draw their container (surface + rounded corners),
/// overriding what the board spec authored.
///
/// Three states rather than a plain on/off, so the default can be "leave the
/// boards alone". A two-state toggle would have to pick a side at boot and would
/// therefore restyle whichever boards disagreed with it — `Board` and `Wide` are
/// authored with chrome, the `focus` family without.
enum ContainerMode: CaseIterable {
    /// Each column as its spec declares it. The default; changes nothing.
    case authored
    /// Force every tile to draw its container.
    case containered
    /// Force every tile chrome-less, straight on the gradient.
    case bare

    /// Switcher labels — kept to ≤5 characters, as the pill sizes every slot to
    /// the widest one.
    var label: String {
        switch self {
        case .authored: "Auto"
        case .containered: "Tile"
        case .bare: "Bare"
        }
    }

    /// Resolves a column's authored flag against this mode.
    func isContainerless(authored: Bool) -> Bool {
        switch self {
        case .authored: authored
        case .containered: false
        case .bare: true
        }
    }
}
