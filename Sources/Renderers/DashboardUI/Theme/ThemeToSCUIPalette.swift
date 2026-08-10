// ThemeToSCUIPalette.swift — Translation: theme tokens to SwiftCrossUI colours, fonts, spacing.

import DashboardKit
import SwiftCrossUI

/// Resolves a DashboardKit `Theme`'s tokens into SwiftCrossUI-native values for
/// one concrete viewport.
///
/// The dev web renderer turns theme tokens into CSS variables; this is the
/// real-UI equivalent — the same tokens, resolved to `Color`/`Font`/spacing so
/// the SwiftCrossUI tiles look like the web preview.
///
/// Size tokens are *not* copied through verbatim: the theme's sizes are authored
/// at `ThemeMetrics.referenceViewport`, and every size here has been scaled by
/// `scale` for the viewport passed in. Build a fresh palette whenever the window
/// size changes (`DashboardRootView` does this from a `GeometryReader`) and the
/// dashboard keeps the same proportions on any screen.
struct ThemeToSCUIPalette: Sendable {
    let background: Color
    /// Top-to-bottom background gradient stops, or `nil` for a flat background.
    let backgroundGradient: [Color]?
    let surface: Color
    let primary: Color
    let secondary: Color
    let accent: Color
    let text: Color
    let muted: Color
    /// Hairline rules inside a tile (`WidgetView.divider`).
    let divider: Color
    /// Outline around a tile, or `nil` when the theme asks for none.
    let border: Color?
    /// The same outline as a CSS colour string. The GTK border is drawn as a CSS
    /// property on the widget itself rather than as an overlaid shape — see
    /// `TileBorderGTK` for why — and that needs the hex, not a `Color`.
    let borderHex: String?
    /// The accent as a CSS colour string, for chrome that must draw an outline
    /// even when the theme defines no border (the header's Edit button).
    let accentHex: String

    let widgetGap: Int
    let tilePadding: Int
    let sectionMargin: Int
    let cornerRadius: Double
    /// Stroke width for the tile outline, scaled like every other size.
    let borderWidth: Double

    /// Vertical counterparts of `tilePadding` / `sectionMargin`, scaled off the
    /// viewport's **height** instead of its width.
    ///
    /// Type scales with width (a wider screen wants bigger type), but vertical
    /// whitespace has to answer to the height it's spending. The Pi's panel is
    /// 1920×440 — 1.5× the reference width but 0.55× its height — so scaling
    /// vertical padding by the type scale spent ~1.5× the room on margins and
    /// pushed the tiles off the bottom of the screen.
    let verticalTilePadding: Int
    let verticalSectionMargin: Int
    let verticalWidgetGap: Int

    let headingSize: Double
    let bodySize: Double
    let captionSize: Double
    let headingWeight: Font.Weight
    let bodyWeight: Font.Weight

    /// The viewport-derived multiplier already baked into every size above.
    /// Views with a one-off size or gap of their own multiply by this to stay in
    /// proportion with the rest of the board.
    let scale: Double
    /// The height-derived multiplier behind the `vertical*` values above. Use it
    /// for one-off *vertical* gaps so they shrink on a short screen.
    let verticalScale: Double

    /// - Parameters:
    ///   - viewport: the window size to resolve sizes for. Defaults to the
    ///     theme's reference canvas, i.e. sizes exactly as authored.
    ///   - scaleMultiplier: a manual nudge applied on top of the viewport-derived
    ///     scale (`--scale N` / `DD_UI_SCALE`), for dialing type in on a real
    ///     display without a rebuild.
    ///   - colorsOverride: a palette to draw in instead of the theme's own, for
    ///     the header's colour-variant pill. `nil` leaves the theme as authored.
    init(
        theme: any Theme,
        viewport: Viewport = .reference,
        scaleMultiplier: Double = 1,
        colorsOverride: ThemeColors? = nil
    ) {
        let sizes = theme.sizes(for: viewport, multiplier: scaleMultiplier)
        scale = sizes.scale

        // Same theme, same clamps, but measured against the height.
        var verticalMetrics = theme.metrics
        verticalMetrics.basis = .height
        let vertical = verticalMetrics.scale(for: viewport)
            * (scaleMultiplier > 0 ? scaleMultiplier : 1)
        verticalScale = vertical

        let colors = colorsOverride ?? theme.colors
        background = Color(hex: colors.background) ?? .black
        let stops = colors.backgroundGradient.compactMap { Color(hex: $0) }
        backgroundGradient = stops.count >= 2 ? stops : nil
        surface = Color(hex: colors.surface) ?? Color(white: 0.1)
        primary = Color(hex: colors.primary) ?? .white
        secondary = Color(hex: colors.secondary) ?? .gray
        accent = Color(hex: colors.accent) ?? .blue
        text = Color(hex: colors.text) ?? .white
        muted = Color(hex: colors.mutedText) ?? .gray
        divider = Color(hex: colors.divider) ?? Color(white: 1, opacity: 0.14)
        border = colors.border.isEmpty ? nil : Color(hex: colors.border)
        borderHex = colors.border.isEmpty ? nil : colors.border
        accentHex = colors.accent

        let spacing = sizes.spacing
        widgetGap = Int(spacing.widgetGap.rounded())
        tilePadding = Int(spacing.tilePadding.rounded())
        sectionMargin = Int(spacing.sectionMargin.rounded())
        cornerRadius = sizes.shape.cornerRadius
        borderWidth = max(1, sizes.shape.borderWidth)

        let authored = theme.spacing
        verticalTilePadding = max(2, Int((authored.tilePadding * vertical).rounded()))
        verticalSectionMargin = max(2, Int((authored.sectionMargin * vertical).rounded()))
        verticalWidgetGap = max(2, Int((authored.widgetGap * vertical).rounded()))

        let typography = sizes.typography
        headingSize = typography.headingSize
        bodySize = typography.bodySize
        captionSize = typography.captionSize
        headingWeight = Font.Weight(cssWeight: typography.headingWeight)
        bodyWeight = Font.Weight(cssWeight: typography.bodyWeight)
    }
}

extension Color {
    /// Parses a `#RRGGBB` / `#RRGGBBAA` (or 3/4-digit) hex string into a color.
    /// Returns `nil` for anything it can't parse, so callers can fall back.
    init?(hex string: String) {
        var hex = string.hasPrefix("#") ? String(string.dropFirst()) : string

        // Expand shorthand (#RGB / #RGBA) to full form.
        if hex.count == 3 || hex.count == 4 {
            hex = String(hex.flatMap { [$0, $0] })
        }

        guard hex.count == 6 || hex.count == 8,
              let value = UInt32(hex, radix: 16) else {
            return nil
        }

        let hasAlpha = hex.count == 8
        let r, g, b, a: Double
        if hasAlpha {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

extension Font.Weight {
    /// Maps a CSS-style numeric weight (100–900) onto the nearest named weight.
    /// Note the order of the two lightest cases: Apple's naming has `ultraLight`
    /// *lighter* than `thin` (100 and 200 respectively), matching CSS. These were
    /// swapped, which capped the theme's `headingWeight: 100` at GTK CSS weight 300
    /// — so a family with genuine Thin/Ultralight faces (SF Pro) still rendered in
    /// Light, and the "thin" look the gradient theme is built around never appeared.
    init(cssWeight: Int) {
        switch cssWeight {
        case ..<150: self = .ultraLight
        case ..<250: self = .thin
        case ..<350: self = .light
        case ..<450: self = .regular
        case ..<550: self = .medium
        case ..<650: self = .semibold
        case ..<750: self = .bold
        case ..<850: self = .heavy
        default: self = .black
        }
    }
}
