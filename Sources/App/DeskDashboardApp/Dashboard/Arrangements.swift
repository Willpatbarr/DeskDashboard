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
    // The one board with a photo behind it. The path is absolute and points at
    // the Pi's checkout, because that is the only machine this board is looked at
    // on; `DD_BG_IMAGE` overrides it for a Mac dev run. `Assets/tea-mist-wide.png`
    // is the Apple "Tea Mist" wallpaper pre-cropped to the panel's 1920×438 strip
    // — nothing crops it at render time, so an uncropped file draws stretched.
    Arrangement(name: "Green · wide clock", short: "Wide",
                screen: .board(BoardColumns.wideClock),
                backgroundImage: "/home/willbarr/Desktop/DeskDashboard-MacMiniDev/Assets/tea-mist-wide.png"),
    Arrangement(name: "Green · focus", short: "Focus",
                screen: .bands(BoardColumns.focus)),
    Arrangement(name: "Green · focus flipped", short: "Flip",
                screen: .board(BoardColumns.focusFlipped)),
    Arrangement(name: "Green · flip centered", short: "Ctr",
                screen: .board(BoardColumns.focusFlippedCentered)),
    // "Ruled · board" was dropped from the switcher to keep the pill row from
    // overflowing the strip when the Claude board joined (8 pills shoved the
    // whole surface right); `BoardColumns.ruled` itself stays, still used by
    // the Claude board's clock column styling reference.
    Arrangement(name: "Gradient · MTG", short: "MTG",
                theme: GradientClockTheme(), screen: .board(BoardColumns.mtg)),
    // Fullscreen: no header, left rail only — reached by the header's `›` arrow,
    // deliberately absent from the switcher pills (see `Arrangement.isFullscreen`).
    // HTMLer: the palette this board was authored in, so it looks the same
    // here as it does in a browser tab. It is a THEME now rather than a pile of
    // constants in the layout, so the hue pill restyles the board like any
    // other — only the colours that mean something (attention, flags, PR) are
    // held fixed.
    Arrangement(name: "Claude · sessions", short: "Claude",
                theme: HTMLerTheme(),
                screen: .board(BoardColumns.claude),
                isFullscreen: true),
]
