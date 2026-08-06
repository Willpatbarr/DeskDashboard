// TextRoleToSCUIStyle.swift — Translation: a semantic `TextRole` to a concrete size, weight and colour.

import DashboardKit
import SwiftCrossUI

/// A `TextRole` resolved to concrete type: this is where the theme decides what
/// "a title" or "the display value" actually looks like.
struct TextRoleToSCUIStyle {
    let size: Double
    let weight: Font.Weight
    let color: Color
    /// Whether the renderer should upper-case the string before drawing it.
    let uppercased: Bool
}

extension ThemeToSCUIPalette {
    /// The concrete style for a semantic role.
    ///
    /// Lives on the palette rather than on `TileView` because it's a *theme*
    /// decision, not an interpreter one — and because every renderer that grows a
    /// `WidgetView` interpreter will need the same mapping.
    func style(for role: TextRole) -> TextRoleToSCUIStyle {
        switch role {
        case .title:
            TextRoleToSCUIStyle(size: captionSize, weight: bodyWeight, color: secondary, uppercased: true)
        case .hero:
            TextRoleToSCUIStyle(size: headingSize * 1.6, weight: headingWeight, color: primary, uppercased: false)
        // Only `.centeredValue` uses this, and only the wide board's 3fr clock
        // column uses that: ~765px wide, ~717px inside the padding. A five-glyph
        // time ("12:34") runs about 2.3× the font size, so width is not the binding
        // constraint here — *height* is. At 3× (207pt) the supporting line below the
        // value ran to y=435 against a tile bottom of 428; 2.6× leaves it clear.
        // Re-check both bounds before reusing this role in a smaller tile.
        case .display:
            TextRoleToSCUIStyle(size: headingSize * 2.6, weight: headingWeight, color: primary, uppercased: false)
        case .primary:
            TextRoleToSCUIStyle(size: headingSize, weight: headingWeight, color: primary, uppercased: false)
        case .secondary:
            TextRoleToSCUIStyle(size: bodySize, weight: bodyWeight, color: text, uppercased: false)
        // A notch under body size: it's a caption-ish line under a display value,
        // and uppercase reads larger than mixed case at the same point size.
        case .subtitle:
            TextRoleToSCUIStyle(size: bodySize * 0.85, weight: bodyWeight, color: secondary, uppercased: true)
        case .caption:
            TextRoleToSCUIStyle(size: captionSize, weight: bodyWeight, color: muted, uppercased: false)
        }
    }
}
