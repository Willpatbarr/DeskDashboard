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
            if role == .display {
                return AnyView(tightenedText(text, style: style))
            }
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
            let lift = Int((largest * 0.11).rounded())

            return AnyView(
                // Negative, because the two labels' own boxes already leave ~50px
                // between the inks at this size; this trims it to the ~26px that
                // reads right.
                VStack(alignment: .center, spacing: Int((largest * -0.13).rounded())) {
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

    /// Draws display text as runs split around its separators, pulled together with
    /// negative stack spacing — the closest thing to letter-spacing available here.
    ///
    /// There is no tracking API: `Font` exposes size, weight and design only, the GTK
    /// backend's CSS property set has no `letter-spacing`, and `Text` doesn't go
    /// through Pango markup.
    ///
    /// Splitting *per character* was the obvious approach and it's wrong: a `Text` is
    /// sized to its **ink**, not to the font's advance, so narrow glyphs lose their
    /// side bearings — the colon is two dots, and its neighbours landed on top of
    /// them. Splitting on separators keeps each digit group a real text run (advances
    /// and kerning intact) and tightens only the joins, which is where the slack is.
    private func tightenedText(
        _ text: String,
        style: (size: Double, weight: Font.Weight, color: Color, uppercased: Bool)
    ) -> some View {
        let runs = Self.separatorRuns(of: text)
        let indexed = Array(runs.enumerated())
        return HStack(spacing: Int((style.size * Self.displayTightening).rounded())) {
            ForEach(indexed, id: \.offset) { item in
                Text(item.element)
                    .font(.system(size: style.size, weight: style.weight))
                    .foregroundColor(style.color)
                    .lineLimit(1)
            }
        }
        // A bare `HStack` reports no height here, which collapses the row and lets the
        // supporting line draw over the value; and the glyphs then sit low in that box,
        // so the line below needs pushing clear and the whole block lifting back up.
        // All three measured on the panel.
        .frame(height: (style.size * 1.3).rounded())
        .padding(.bottom, Int((style.size * 0.50).rounded()))
        .padding(.top, -Int((style.size * 0.60).rounded()))
    }

    /// How far to pull display runs together, as a fraction of the font size.
    /// Tuned on the panel: tight without the digits touching the colon.
    private static let displayTightening = -0.05

    /// Splits `text` into alphanumeric runs and the separators between them, e.g.
    /// `"12:30"` -> `["12", ":", "30"]`.
    private static func separatorRuns(of text: String) -> [String] {
        var runs: [String] = []
        var current = ""
        for character in text {
            let isSeparator = !character.isLetter && !character.isNumber
            if isSeparator {
                if !current.isEmpty { runs.append(current); current = "" }
                runs.append(String(character))
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { runs.append(current) }
        return runs
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
        // A notch under body size: it's a caption-ish line under a display value,
        // and uppercase reads larger than mixed case at the same point size.
        case .subtitle:  (palette.bodySize * 0.85, palette.bodyWeight, palette.secondary, true)
        case .caption:   (palette.captionSize, palette.bodyWeight, palette.muted, false)
        }
    }
}
