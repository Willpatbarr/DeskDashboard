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
    /// An absolute path to a photo to draw behind everything, or `nil` for the
    /// theme's own flat/gradient background.
    ///
    /// Deliberately on the *arrangement* rather than the `Theme`: a wallpaper is a
    /// per-board presentation choice, and putting it here lets one board carry a
    /// photo without forking a whole theme (and without every other board that
    /// shares that theme inheriting it).
    ///
    /// `png`, `jpg` or `webp` only — SwiftCrossUI's `Image` cannot decode heic, so
    /// an Apple wallpaper must be converted first. Nothing scales or crops it at
    /// render time (there is no aspect-fill on this backend), so pre-crop the file
    /// to the panel's aspect or it will draw stretched.
    public let backgroundImage: String?

    /// The screens the renderer knows how to draw.
    ///
    /// Only boards, now. There used to be a hand-built `.mtg` case for the Magic
    /// tracker; once widgets could accept input it became an ordinary board of
    /// widgets, so the renderer no longer carries a bespoke screen — or the
    /// product knowledge that one of its screens is a game.
    public enum Screen: Equatable, Sendable {
        /// A single-row board with proportional column widths — see `BoardColumn`.
        case board([BoardColumn])
        /// A board of stacked full-width bands, each its own row of columns with a
        /// proportional height — see `BoardBand`. Use this when a widget has to
        /// span the whole board above or below others; `.board` is the one-band
        /// shorthand and renders through the same path.
        case bands([BoardBand])
    }

    public init(
        name: String,
        short: String,
        theme: (any Theme)? = nil,
        screen: Screen? = nil,
        backgroundImage: String? = nil
    ) {
        self.name = name
        self.short = short
        self.theme = theme
        self.screen = screen
        self.backgroundImage = backgroundImage
    }
}
