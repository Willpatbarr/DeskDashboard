// TransportGlyphs.swift — Play and pause glyphs drawn as vector paths rather than font characters.

import SwiftCrossUI

// Play/pause glyphs as vector paths rather than font characters: the panel's
// font coverage isn't something to bet a control indicator on, and `Shape`
// renders through the backend's path support, which the progress row already
// relies on.

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
