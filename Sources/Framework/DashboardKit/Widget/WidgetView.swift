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
    /// The main value at normal heading size.
    case primary
    /// Supporting line under the primary value.
    case secondary
    /// De-emphasized fine print (metadata).
    case caption
}
