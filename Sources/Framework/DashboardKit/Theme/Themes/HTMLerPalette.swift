// HTMLerPalette.swift — The AgentManager web dashboard's palette, for the HTML hue.

import Foundation

public extension ThemeColors {
    /// The palette the AgentManager web board is authored in
    /// (`public/index.html`'s `:root`), lifted verbatim so the Claude session
    /// board looks the same on the Pi as it does in a browser tab.
    ///
    /// Copied rather than approximated on purpose: the point of this theme is
    /// that the two surfaces match, so any drift here is a bug, not a taste
    /// call. If the web board's `:root` changes, change these with it.
    ///
    /// `surfaceRaised` is what makes it work as a theme rather than a pile of
    /// constants: the board has THREE depths — page, column well, card — and
    /// every other theme only names two.
    static let htmler = Self(
        // --bg
        background: "#101216",
        // --col-bg: the column wells.
        surface: "#15181d",
        primary: "#e8eaed",
        // --dim
        secondary: "#9aa0a8",
        // The board's "working" green. Chrome (pills, highlights) wears this.
        accent: "#4ade80",
        // --text
        text: "#e8eaed",
        mutedText: "#9aa0a8",
        backgroundGradient: [],
        // --line, for both rules and outlines.
        divider: "#2a2f37",
        border: "#2a2f37",
        // --card: one step up from the wells.
        surfaceRaised: "#1d2229"
    )
}
