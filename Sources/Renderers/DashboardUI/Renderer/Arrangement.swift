// Arrangement.swift — One selectable arrangement: a screen plus an optional theme of its own.

import DashboardKit

/// One selectable way to arrange the dashboard: a screen, optionally with a theme
/// of its own.
///
/// These are the app's **production configuration**, not a debug feature. The app
/// declares its arrangements and hands them to `SwiftCrossUIRenderer`; the
/// switcher in the header just picks among them, and hiding it (`--kiosk`)
/// changes nothing about what renders.
///
/// They used to be called "previews" and lived inside this module as a hardcoded
/// catalogue, which made the renderer own product decisions (which boards exist,
/// that one of them is a Magic life counter) and left the composition's own theme
/// painting nothing.
public struct Arrangement: Sendable {
    /// Full name for the header line.
    public let name: String
    /// Short label for a switcher segment — keep it ≤5 characters; the pill sizes
    /// every slot to the widest one.
    public let short: String
    /// A theme just for this arrangement, or `nil` to use the dashboard's own
    /// configured theme (`Dashboard.configuration.theme`).
    public let theme: (any Theme)?
    /// The screen that fills the content region, or `nil` for the ordinary tile
    /// grid laid out from each widget's `WidgetSize` and its own `layout`.
    public let screen: Screen?

    /// The screens the renderer knows how to draw.
    public enum Screen: Equatable, Sendable {
        /// Interactive Magic: The Gathering life/turn tracker.
        case mtg
        /// A single-row board with proportional column widths — see `BoardColumn`.
        case board([BoardColumn])
    }

    public init(
        name: String,
        short: String,
        theme: (any Theme)? = nil,
        screen: Screen? = nil
    ) {
        self.name = name
        self.short = short
        self.theme = theme
        self.screen = screen
    }
}
