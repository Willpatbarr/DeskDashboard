// Arrangements.swift — This dashboard's arrangements, in switcher order.

import DashboardKit
import DashboardUI

// This dashboard's production configuration: the ways it can be arranged, in
// switcher order. Index 0 is what the kiosk boots into.
//
// This lives in the **app**, not the renderer, because which boards exist — and
// that one of them is a Magic: The Gathering life counter — is a product
// decision. `DashboardUI` only knows how to draw a board or the MTG screen; it
// no longer knows which ones this dashboard wants.
//
// Boards themselves are one file each in this folder (`FocusBoard.swift`, …).
//
// Themes: an arrangement leaves `theme` nil to use the dashboard's own configured
// theme (see `Composition.swift`), so the composition is genuinely the source of
// truth. MTG is the one exception — it names its own.

let dashboardArrangements: [Arrangement] = [
    Arrangement(name: "Green · board", short: "Board",
                screen: .board(BoardColumns.equalWidths)),
    Arrangement(name: "Green · wide clock", short: "Wide",
                screen: .board(BoardColumns.wideClock)),
    Arrangement(name: "Green · focus", short: "Focus",
                screen: .board(BoardColumns.focus)),
    Arrangement(name: "Green · focus flipped", short: "Flip",
                screen: .board(BoardColumns.focusFlipped)),
    Arrangement(name: "Green · flip centered", short: "Ctr",
                screen: .board(BoardColumns.focusFlippedCentered)),
    Arrangement(name: "Ruled · board", short: "Ruled",
                theme: RuledGreenTheme(), screen: .board(BoardColumns.ruled)),
    Arrangement(name: "Gradient · MTG", short: "MTG",
                theme: GradientClockTheme(), screen: .board(BoardColumns.mtg)),
]
