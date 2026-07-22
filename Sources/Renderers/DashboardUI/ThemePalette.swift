import DashboardKit
import SwiftCrossUI

/// Resolves a DashboardKit `Theme`'s tokens into SwiftCrossUI-native values.
///
/// The dev web renderer turns theme tokens into CSS variables; this is the
/// real-UI equivalent — the same tokens, resolved to `Color`/`Font`/spacing so
/// the SwiftCrossUI tiles look like the web preview.
struct ThemePalette: Sendable {
    let background: Color
    /// Top-to-bottom background gradient stops, or `nil` for a flat background.
    let backgroundGradient: [Color]?
    let surface: Color
    let primary: Color
    let secondary: Color
    let accent: Color
    let text: Color
    let muted: Color

    let widgetGap: Int
    let tilePadding: Int
    let sectionMargin: Int
    let cornerRadius: Double

    let headingSize: Double
    let bodySize: Double
    let captionSize: Double
    let headingWeight: Font.Weight
    let bodyWeight: Font.Weight

    init(theme: any Theme) {
        let colors = theme.colors
        background = Color(hex: colors.background) ?? .black
        let stops = colors.backgroundGradient.compactMap { Color(hex: $0) }
        backgroundGradient = stops.count >= 2 ? stops : nil
        surface = Color(hex: colors.surface) ?? Color(white: 0.1)
        primary = Color(hex: colors.primary) ?? .white
        secondary = Color(hex: colors.secondary) ?? .gray
        accent = Color(hex: colors.accent) ?? .blue
        text = Color(hex: colors.text) ?? .white
        muted = Color(hex: colors.mutedText) ?? .gray

        let spacing = theme.spacing
        widgetGap = Int(spacing.widgetGap.rounded())
        tilePadding = Int(spacing.tilePadding.rounded())
        sectionMargin = Int(spacing.sectionMargin.rounded())
        cornerRadius = theme.shape.cornerRadius

        let typography = theme.typography
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
    init(cssWeight: Int) {
        switch cssWeight {
        case ..<150: self = .thin
        case ..<250: self = .ultraLight
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
