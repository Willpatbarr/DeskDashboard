// WidgetView.swift — Backend-agnostic tile structure: semantic nodes and text roles, no fonts or pixels.

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
    /// A hairline rule across the tile's width, in the theme's `divider` colour.
    /// Separates a tile's label from its body, or its body from its footer.
    case divider
    /// A thin horizontal progress line, filled to the given fraction (0…1).
    case progressBar(Double)
    /// A small play (true) / pause (false) glyph.
    case playState(playing: Bool)
    /// A single line of text sized by the renderer to fill whatever space the
    /// node is given — the value scales with the widget, instead of taking a
    /// fixed role size.
    case fittedText(String)
    /// Makes its child tappable — and optionally hold-able — reporting an action
    /// name back to the widget.
    ///
    /// The action is a NAME, not a closure, so a `WidgetView` stays `Equatable`
    /// and `Sendable` and layouts stay pure data that any renderer can interpret.
    /// A renderer that doesn't handle input can simply draw the child.
    /// The widget receives it via `InteractiveWidget.handle(action:environment:)`.
    /// `hold` fires on a long press instead of `action`; nil means a hold does
    /// nothing. Both are names, so a renderer without a long-press gesture can
    /// honour the tap and ignore the hold.
    case tappable(action: String, hold: String?, WidgetView)

    /// Gives its child a REGION at least `minWidth`×`minHeight`, independently of the
    /// ink inside it.
    ///
    /// Two uses, both about a region outgrowing its ink. A tap lands on a widget's
    /// allocated region, not on its glyphs — a `+` drawn 30px tall is a 30px target
    /// however much room its tile has, which is miserable to hit on a touchscreen.
    /// And a label offered a single line's height will ellipsize rather than wrap,
    /// so reserving two lines is how a layout says "this one is allowed to run on".
    ///
    /// Deliberately a MINIMUM rather than "fill the parent". Two greedy siblings do
    /// not split leftover space evenly on this backend — measured 116px against 80px
    /// — which silently pulled a centred value 30px off centre. An explicit minimum
    /// leaves the surrounding spacers to do the centring, as they already did.
    ///
    /// Sizes are in reference-canvas units like every other measurement here; the
    /// renderer scales them. A renderer with no notion of hit areas can ignore the
    /// wrapper and draw the child.
    case region(minWidth: Double, minHeight: Double, WidgetView)
}

public extension WidgetView {
    /// A region at least `size`×`size`, for a control whose ink is smaller than a
    /// fingertip.
    static func touchTarget(_ size: Double, _ child: WidgetView) -> WidgetView {
        .region(minWidth: size, minHeight: size, child)
    }

    /// A full-width band at least `minHeight` tall — a control that should be hit
    /// anywhere across its strip of the tile, not just on its glyph.
    static func touchBand(_ minHeight: Double, _ child: WidgetView) -> WidgetView {
        .region(minWidth: 0, minHeight: minHeight, child)
    }
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
