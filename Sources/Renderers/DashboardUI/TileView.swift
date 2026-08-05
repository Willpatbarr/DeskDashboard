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
            // A thin line: accent fill over a surface-coloured track. Widths are
            // computed from a GeometryReader (there is no proportional-split
            // primitive); it reports 0×0 on early passes, which just renders an
            // empty bar until the real size arrives a pass later. The segments
            // are framed, backgrounded stacks — a bare stack reports no size.
            let barHeight = max(3, Int((4 * palette.scale).rounded()))
            return AnyView(
                GeometryReader { proxy in
                    // The reader can report 0×0 on early passes and an INFINITE
                    // width on probe passes (Int(inf) is a fatal trap — crashed
                    // the app on the panel). Treat anything non-finite as "size
                    // unknown" and draw nothing until a real width arrives.
                    let raw = proxy.size.width
                    let width = raw.isFinite ? max(0, raw) : 0
                    let fill = (width * min(1, max(0, fraction))).rounded()
                    HStack(spacing: 0) {
                        HStack(spacing: 0) {}
                            .frame(width: Int(fill), height: barHeight)
                            .background(palette.accent)
                        HStack(spacing: 0) {}
                            .frame(width: Int(width - fill), height: barHeight)
                            .background(palette.surface)
                    }
                }
                .frame(height: Double(barHeight))
            )

        case let .fittedText(string):
            // Sized to fill whatever region the node was given, so the value
            // scales with its tile. The size is estimated from glyph metrics
            // (SwiftCrossUI exposes no text measurement to app code): thin SF
            // digits run ~0.62em wide, and the ink needs ~1.0em of box height.
            let weight = palette.headingWeight
            let color = palette.primary
            return AnyView(
                GeometryReader { proxy in
                    // Non-finite = probe pass; 0×0 = early pass. Both mean
                    // "size unknown" — render at a tiny size until real
                    // geometry arrives (Int(inf) is a fatal trap).
                    let w = proxy.size.width.isFinite ? max(0, proxy.size.width) : 0
                    let h = proxy.size.height.isFinite ? max(0, proxy.size.height) : 0
                    let widthBound = w / (0.62 * Double(max(1, string.count)))
                    // The height bound is the size whose corrected box (~1.2× the
                    // font size, see below) still fits the region — a label
                    // taller than its frame pushes its glyphs down and out (the
                    // 78°F ran off the bottom of the panel at `min(widthBound, h)`).
                    let size = max(8, min(widthBound, h * 0.72))
                    VStack(alignment: .center, spacing: 0) {
                        Spacer(minLength: 0)
                        // Same corrective wrapper as `tightenedText`: glyphs sit
                        // LOW in a big label's box on this backend, so centring
                        // the raw box put the ink near the region's bottom (79°F
                        // rendered half off-screen). Frame + push + lift are the
                        // panel-measured constants that put the ink where the
                        // box is.
                        HStack(spacing: 0) {
                            Text(string)
                                .font(.system(size: size, weight: weight))
                                .foregroundColor(color)
                                .lineLimit(1)
                        }
                        .frame(height: (size * 1.3).rounded())
                        .padding(.bottom, Int((size * 0.50).rounded()))
                        .padding(.top, -Int((size * 0.60).rounded()))
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                }
            )

        case let .playState(playing):
            let side = max(8, Int(palette.captionSize.rounded()))
            return AnyView(
                Group {
                    if playing {
                        PlayGlyph().fill(palette.secondary)
                    } else {
                        PauseGlyph().fill(palette.secondary)
                    }
                }
                .frame(width: side, height: side)
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

    /// Draws display text as ONE run with real negative letter-spacing, via
    /// `Text.displayTracking(pixels:)` (see `DisplayTracking.swift` — GTK CSS on the
    /// backing label). The earlier approach — splitting into runs joined by negative
    /// HStack spacing — could never be tight without collision: a `Text` is sized to
    /// its ink, so the colon (two dots, wide bearings) kept getting overrun by its
    /// neighbours. A single tracked run keeps kerning and side bearings intact.
    private func tightenedText(
        _ text: String,
        style: (size: Double, weight: Font.Weight, color: Color, uppercased: Bool)
    ) -> some View {
        let run = Text(text)
            .displayTracking(pixels: Int((style.size * Self.displayTracking).rounded()))
        // The HStack wrapper (not the label itself) carries the sizing hacks, same
        // as the old run-split version, so the measured constants still apply:
        // a bare `HStack` reports no height here, which collapses the row and lets
        // the supporting line draw over the value; and the glyphs then sit low in
        // that box, so the line below needs pushing clear and the whole block
        // lifting back up. All three measured on the panel.
        return HStack(spacing: 0) {
            run
                .font(.system(size: style.size, weight: style.weight))
                .foregroundColor(style.color)
                .lineLimit(1)
        }
        .frame(height: (style.size * 1.3).rounded())
        .padding(.bottom, Int((style.size * 0.50).rounded()))
        .padding(.top, -Int((style.size * 0.60).rounded()))
    }

    /// Display-text tracking as a fraction of the font size: ≈ −10px at the wide
    /// board's display size (headingSize × 2.6 ≈ 186px on the 1920×440 panel).
    private static let displayTracking = -0.054

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

// MARK: - Transport glyphs

/// A right-pointing play triangle filling its bounds.
struct PlayGlyph: Shape {
    nonisolated func path(in bounds: Path.Rect) -> Path {
        Path()
            .move(to: SIMD2(bounds.x, bounds.y))
            .addLine(to: SIMD2(bounds.x + bounds.width, bounds.y + bounds.height / 2))
            .addLine(to: SIMD2(bounds.x, bounds.y + bounds.height))
            .addLine(to: SIMD2(bounds.x, bounds.y))
    }
}

/// Two vertical pause bars filling their bounds.
struct PauseGlyph: Shape {
    nonisolated func path(in bounds: Path.Rect) -> Path {
        let barWidth = bounds.width * 0.35
        return Path()
            .addRectangle(Path.Rect(
                x: bounds.x, y: bounds.y,
                width: barWidth, height: bounds.height
            ))
            .addRectangle(Path.Rect(
                x: bounds.x + bounds.width - barWidth, y: bounds.y,
                width: barWidth, height: bounds.height
            ))
    }
}
