import DashboardKit
import SwiftCrossUI

/// Renders one widget tile by interpreting a `WidgetView` tree into SwiftCrossUI
/// views. The tree comes from the widget's chosen `WidgetLayout`; this view owns
/// the *look* — it resolves each `TextRole` to a concrete font + color from the
/// theme `palette`, and wraps the content in the tile chrome (padding, surface,
/// corner radius).
struct TileView: View {
    let snapshot: AttachedWidgetSnapshot
    let palette: ThemePalette
    /// When set (preview mode), forces this layout on every tile; otherwise the
    /// widget's own `configuration.layout` is used.
    var layoutOverride: WidgetLayout? = nil

    /// Semantic content for the layout: real content when present, otherwise the
    /// configured title + a placeholder so an unrendered tile isn't blank.
    private var content: WidgetContent {
        WidgetContent(
            title: snapshot.content?.title ?? snapshot.configuration.title,
            primaryText: snapshot.content?.primaryText ?? "…",
            secondaryText: snapshot.content?.secondaryText,
            accessoryText: snapshot.content?.accessoryText,
            metadata: snapshot.content?.metadata ?? []
        )
    }

    var body: some View {
        let layout = layoutOverride ?? snapshot.configuration.layout
        return interpret(layout.makeView(content))
            .padding(.horizontal, palette.tilePadding)
            .padding(.vertical, palette.verticalTilePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.surface)
            .cornerRadius(Int(palette.cornerRadius.rounded()))
    }

    // MARK: - Interpreter (WidgetView -> SwiftCrossUI)

    private func interpret(_ node: WidgetView) -> AnyView {
        switch node {
        case let .text(string, role):
            let style = style(for: role)
            let text = style.uppercased ? string.uppercased() : string
            // Note: do NOT try to lift display text with a shorter `.frame(height:)`.
            // A frame smaller than the label's natural box does not centre the text
            // here — it pushes the glyphs *down* and out of their box, so the
            // supporting line gets drawn straight through them (verified on the
            // panel twice now).
            return AnyView(
                Text(text)
                    .font(.system(size: style.size, weight: style.weight))
                    .foregroundColor(style.color)
            )

        case let .badge(string):
            return AnyView(
                Text(string)
                    .font(.system(size: palette.captionSize, weight: .bold))
                    .foregroundColor(palette.accent)
            )

        case .spacer:
            return AnyView(Spacer(minLength: 0))

        case let .centered(children):
            let views = children.map(interpret)
            let indexed = Array(views.enumerated())

            // Lift the group by the ascent its largest text reserves above its cap
            // height (~0.17× the font size), so a big value's glyph top lines up with
            // the smaller values in neighbouring tiles instead of sitting lower.
            let largest = children.reduce(0.0) { widest, child in
                if case let .text(_, role) = child {
                    return max(widest, style(for: role).size)
                }
                return widest
            }
            let lift = Int((largest * 0.17).rounded())

            return AnyView(
                VStack(alignment: .center, spacing: Int((2 * palette.verticalScale).rounded())) {
                    ForEach(indexed, id: \.offset) { $0.element }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, -lift)
            )

        case let .stack(axis, spacing, children):
            let views = children.map(interpret)
            let indexed = Array(views.enumerated())
            // Layout spacings are authored against the theme's reference canvas
            // like every other size, so scale them with the palette.
            let gap = Int((spacing * palette.scale).rounded())
            switch axis {
            case .vertical:
                return AnyView(
                    VStack(alignment: .leading, spacing: gap) {
                        ForEach(indexed, id: \.offset) { $0.element }
                    }
                )
            case .horizontal:
                return AnyView(
                    HStack(spacing: gap) {
                        ForEach(indexed, id: \.offset) { $0.element }
                    }
                )
            }
        }
    }

    // MARK: - Role -> concrete style (the theme decides the look)

    private func style(
        for role: TextRole
    ) -> (size: Double, weight: Font.Weight, color: Color, uppercased: Bool) {
        switch role {
        case .title:     (palette.captionSize, palette.bodyWeight, palette.secondary, true)
        case .hero:      (palette.headingSize * 1.6, palette.headingWeight, palette.primary, false)
        // Only `.centeredValue` uses this, and only the wide board's 3fr clock
        // column uses that: ~765px wide, ~717px inside the padding. A five-glyph
        // time ("12:34") runs about 2.3× the font size, so width is not the binding
        // constraint here — *height* is. At 3× (207pt) the supporting line below the
        // value ran to y=435 against a tile bottom of 428; 2.6× leaves it clear.
        // Re-check both bounds before reusing this role in a smaller tile.
        case .display:   (palette.headingSize * 2.6, palette.headingWeight, palette.primary, false)
        case .primary:   (palette.headingSize, palette.headingWeight, palette.primary, false)
        case .secondary: (palette.bodySize, palette.bodyWeight, palette.text, false)
        case .caption:   (palette.captionSize, palette.bodyWeight, palette.muted, false)
        }
    }
}
