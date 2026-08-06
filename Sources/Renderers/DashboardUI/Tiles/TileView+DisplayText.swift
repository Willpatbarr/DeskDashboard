// TileView+DisplayText.swift — Tile node: the display-size text run, with real negative letter-spacing.

import SwiftCrossUI

// The `.display` role's text run. Split out of the interpreter because it carries
// the letter-spacing lever plus three panel-measured sizing constants, none of
// which have anything to do with dispatching a `WidgetView` tree.

extension TileView {
    /// Draws display text as ONE run with real negative letter-spacing, via
    /// `Text.displayTracking(pixels:)` (see `TextToGTKTracking.swift` — GTK CSS on the
    /// backing label). The earlier approach — splitting into runs joined by negative
    /// HStack spacing — could never be tight without collision: a `Text` is sized to
    /// its ink, so the colon (two dots, wide bearings) kept getting overrun by its
    /// neighbours. A single tracked run keeps kerning and side bearings intact.
    func tightenedText(
        _ text: String,
        style: TextRoleToSCUIStyle
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
    static let displayTracking = -0.054
}
