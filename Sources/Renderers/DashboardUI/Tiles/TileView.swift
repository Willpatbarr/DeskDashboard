// TileView.swift — Tile chrome plus the dispatcher that interprets a `WidgetView` tree into views.

import DashboardKit
import SwiftCrossUI

/// Renders one widget tile by interpreting a `WidgetView` tree into SwiftCrossUI
/// views. The tree comes from the widget's chosen `WidgetLayout`; this view owns
/// the *look* — it resolves each `TextRole` to a concrete font + color from the
/// theme `palette`, and wraps the content in the tile chrome (padding, surface,
/// corner radius).
///
/// This file is the chrome plus the dispatcher. The node renderers with real
/// geometry in them live alongside it:
/// - `TileView+DisplayText.swift` — the tracked `.display` run
/// - `TileView+FittedText.swift` — the self-sizing value
/// - `TileView+Transport.swift` — progress line, play/pause
/// - `TextRoleToSCUIStyle.swift` — role → concrete type (on `ThemeToSCUIPalette`)
/// - `TransportGlyphs.swift` — the glyph paths
///
/// They're methods on `TileView` rather than separate `View` types on purpose:
/// wrapping a node in another view changes the view-graph shape, and this backend
/// has twice produced blank or collapsed output from exactly that kind of change.
struct TileView: View {
    let snapshot: AttachedWidgetSnapshot
    let palette: ThemeToSCUIPalette
    /// When set (preview mode), forces this layout on every tile; otherwise the
    /// widget's own `configuration.layout` is used.
    var layoutOverride: WidgetLayout? = nil
    /// Drops the tile chrome (surface + corners) for this render, regardless of
    /// the widget's own `isContainerless` — a board-level override, like
    /// `layoutOverride`.
    var containerless: Bool = false
    /// Suppresses the widget's title label for this render (a board-level
    /// choice — every layout already omits an absent title).
    var hidesTitle: Bool = false

    /// Semantic content for the layout: real content when present, otherwise the
    /// configured title + a placeholder so an unrendered tile isn't blank.
    private var content: WidgetContent {
        WidgetContent(
            title: hidesTitle ? nil : (snapshot.content?.title ?? snapshot.configuration.title),
            primaryText: snapshot.content?.primaryText ?? "…",
            secondaryText: snapshot.content?.secondaryText,
            accessoryText: snapshot.content?.accessoryText,
            progress: snapshot.content?.progress,
            elapsedText: snapshot.content?.elapsedText,
            durationText: snapshot.content?.durationText,
            isPlaying: snapshot.content?.isPlaying,
            metadata: snapshot.content?.metadata ?? []
        )
    }

    var body: some View {
        let layout = layoutOverride ?? snapshot.configuration.layout
        // Containerless switches VALUES only (clear surface, square corners) —
        // never the modifier chain. Branching the view structure here blanked
        // every board on the panel, and a chrome-less tile still needs the
        // background wrapper anyway: a stack with no background reports no size
        // on the GTK backend.
        let plain = containerless || snapshot.configuration.isContainerless
        return interpret(layout.makeView(content))
            .padding(.horizontal, palette.tilePadding)
            .padding(.vertical, palette.verticalTilePadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(plain ? Color.clear : palette.surface)
            .cornerRadius(plain ? 0 : Int(palette.cornerRadius.rounded()))
    }

    // MARK: - Interpreter (WidgetView -> SwiftCrossUI)

    private func interpret(_ node: WidgetView) -> AnyView {
        switch node {
        case let .text(string, role):
            let style = palette.style(for: role)
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

            let largest = children.reduce(0.0) { widest, child in
                if case let .text(_, role) = child {
                    return max(widest, palette.style(for: role).size)
                }
                return widest
            }

            // Lift the group by the ascent its FIRST line reserves above its cap
            // height (~0.17× the font size), so a big value's glyph top lines up with
            // the smaller values in neighbouring tiles instead of sitting lower.
            //
            // First line, not the largest: the lift cancels the gap above the group's
            // top edge, which only the top line contributes. Sizing it from the
            // largest was equivalent while the value always came first — but with
            // `centeredValue(subtitle: .above)` the group starts with a subtitle, and
            // a display-sized 20px lift dragged it clean off the top of the tile
            // (measured on the panel: the date rendered 13px tall instead of 26).
            let leadingSize = children.lazy.compactMap { child -> Double? in
                if case let .text(_, role) = child { return palette.style(for: role).size }
                return nil
            }.first ?? 0
            let lift = Int((leadingSize * 0.11).rounded())

            return AnyView(
                // Negative, because the two labels' own boxes already leave ~50px
                // between the inks at this size; this trims it to ~44px. (−0.13 /
                // ~26px read too tight under the single-run tracked clock —
                // measured 27px ink gap on the panel, 2026-08-04.)
                VStack(alignment: .center, spacing: Int((largest * -0.03).rounded())) {
                    ForEach(indexed, id: \.offset) { $0.element }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, -lift)
            )

        case let .progressBar(fraction):
            return AnyView(progressBar(fraction: fraction))

        case let .fittedText(string):
            return AnyView(fittedText(string))

        case let .playState(playing):
            return AnyView(playState(playing: playing))

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
}
