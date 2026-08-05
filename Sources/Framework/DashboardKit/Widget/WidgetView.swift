/// A backend-agnostic description of a tile's structure — semantic, not visual.
///
/// Widgets never build this directly; a `WidgetLayout` maps a widget's
/// `WidgetContent` into a `WidgetView`, and each renderer interprets the tree
/// into its own backend (SwiftCrossUI views, HTML, terminal text). Nodes carry
/// *roles*, not fonts/colors — the renderer + theme resolve the actual look, so
/// the layout stays reusable across every renderer.
public indirect enum WidgetView: Equatable, Sendable {
    /// A run of text in a semantic role (the renderer picks the font/color).
    case text(String, role: TextRole)
    /// A small pill/badge (e.g. "PAUSED", "STALE").
    case badge(String)
    /// Flexible empty space that pushes siblings apart.
    case spacer
    /// A horizontal or vertical arrangement of child views.
    case stack(Axis, spacing: Double, [WidgetView])
    /// Children stacked vertically and centred across the tile's full width.
    /// Everything else is leading-aligned, so this is how a layout asks for the
    /// centred treatment without changing how the rest of the tree is laid out.
    case centered([WidgetView])
    /// A thin horizontal progress line, filled to the given fraction (0…1).
    case progressBar(Double)
    /// A small play (true) / pause (false) glyph.
    case playState(playing: Bool)
    /// A single line of text sized by the renderer to fill whatever space the
    /// node is given — the value scales with the widget, instead of taking a
    /// fixed role size.
    case fittedText(String)
}

public enum Axis: Sendable {
    case horizontal
    case vertical
}

/// The semantic weight of a piece of text. The renderer maps each role to a
/// concrete font + color from the active theme.
public enum TextRole: Sendable {
    /// Small uppercase label (the tile's title).
    case title
    /// The oversized display value (e.g. a big clock/number layout).
    case hero
    /// Larger than `hero`, for a value that is the whole point of its tile — the
    /// board's clock, say, which has a 3fr column to fill.
    case display
    /// The main value at normal heading size.
    case primary
    /// Supporting line under the primary value.
    case secondary
    /// Supporting line rendered like the tile's label — uppercase, in the label
    /// colour — but at body size. Pairs with `display` in `centeredValue`.
    case subtitle
    /// De-emphasized fine print (metadata).
    case caption
}
