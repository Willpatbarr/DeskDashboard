// TileWidthEstimate.swift — How wide a `WidgetView` tree wants to be, estimated from glyph metrics.

import DashboardKit
import SwiftCrossUI

extension ThemeToSCUIPalette {
    /// Estimated width of a laid-out `WidgetView` tree, in points, EXCLUDING the
    /// tile's own padding.
    ///
    /// This exists because SwiftCrossUI exposes no text measurement to app code and
    /// a tile cannot be made to hug its content by frames alone: `TileView` composites
    /// a background, and a background fills whatever width the stack proposes, so a
    /// `maxWidth: nil` frame still comes back full-width (measured on the panel — the
    /// "hugging" temp tiles came out ~550px against ~200px of content).
    ///
    /// So a hugging board column gets an explicit width from here instead. Same
    /// ~0.62em-per-glyph estimate `SwitcherPill`'s slots are sized with, and the same
    /// caveat: it's an ESTIMATE. Round it up at the call site rather than trusting it
    /// to the pixel, and don't use it for anything that must not clip.
    func estimatedWidth(of node: WidgetView) -> Double {
        switch node {
        case let .text(string, role):
            return Double(string.count) * style(for: role).size * Self.glyphWidthRatio
        case let .badge(string):
            return Double(string.count) * captionSize * Self.glyphWidthRatio
        case let .fittedText(string):
            // A fitted value is sized to its REGION, not its text, so there's no
            // honest intrinsic width here. Its heading-size equivalent is the
            // closest thing to an answer.
            return Double(string.count) * headingSize * Self.glyphWidthRatio
        case .spacer, .divider, .progressBar:
            // A spacer wants nothing; the other two are greedy and would make any
            // tile containing them full-width, which is not a hugging tile.
            return 0
        case .playState:
            return captionSize * 1.4
        case let .tappable(_, _, child):
            return estimatedWidth(of: child)
        case let .region(minWidth, _, child):
            return max(minWidth * scale, estimatedWidth(of: child))
        case let .centered(children):
            return children.map { estimatedWidth(of: $0) }.max() ?? 0
        case let .stack(axis, spacing, children):
            let widths = children.map { estimatedWidth(of: $0) }
            switch axis {
            case .horizontal:
                let gaps = spacing * scale * Double(max(0, children.count - 1))
                return widths.reduce(0, +) + gaps
            case .vertical:
                return widths.max() ?? 0
            }
        }
    }

    /// Advance width of a glyph as a fraction of the font size, for thin SF digits
    /// and mixed-case labels at these weights. Shared with `SwitcherPill`'s slot
    /// sizing, where it was arrived at by measurement on the panel.
    static let glyphWidthRatio = 0.62
}
