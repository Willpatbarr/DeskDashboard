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
        interpret(snapshot.configuration.layout.makeView(content))
            .padding(palette.tilePadding)
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

        case let .stack(axis, spacing, children):
            let views = children.map(interpret)
            let indexed = Array(views.enumerated())
            switch axis {
            case .vertical:
                return AnyView(
                    VStack(alignment: .leading, spacing: Int(spacing)) {
                        ForEach(indexed, id: \.offset) { $0.element }
                    }
                )
            case .horizontal:
                return AnyView(
                    HStack(spacing: Int(spacing)) {
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
        case .primary:   (palette.headingSize, palette.headingWeight, palette.primary, false)
        case .secondary: (palette.bodySize, palette.bodyWeight, palette.text, false)
        case .caption:   (palette.captionSize, palette.bodyWeight, palette.muted, false)
        }
    }
}
