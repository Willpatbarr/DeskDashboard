// TileView+FittedText.swift — Tile node: text scaled to fill the region it's handed.

import SwiftCrossUI

// The `.fittedText` node: a value sized to fill whatever region it's handed, so
// the number scales with its tile. Split out because the estimation and the
// ink-correction constants are a self-contained problem.

extension TileView {
    /// Sized to fill whatever region the node was given, so the value
    /// scales with its tile. The size is estimated from glyph metrics
    /// (SwiftCrossUI exposes no text measurement to app code): thin SF
    /// digits run ~0.62em wide, and the ink needs ~1.0em of box height.
    func fittedText(_ string: String) -> some View {
        let weight = palette.headingWeight
        let color = palette.primary
        return GeometryReader { proxy in
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
    }
}
