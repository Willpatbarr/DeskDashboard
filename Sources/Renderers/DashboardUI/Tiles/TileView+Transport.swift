// TileView+Transport.swift — Tile nodes: the progress line and the play/pause indicator.

import SwiftCrossUI

// The transport row's two node renderers: the progress line and the play/pause
// indicator. Both are geometry-heavy enough to bury the interpreter's dispatch.

extension TileView {
    /// A thin line: accent fill over a surface-coloured track. Widths are
    /// computed from a GeometryReader (there is no proportional-split
    /// primitive); it reports 0×0 on early passes, which just renders an
    /// empty bar until the real size arrives a pass later. The segments
    /// are framed, backgrounded stacks — a bare stack reports no size.
    func progressBar(fraction: Double) -> some View {
        let barHeight = max(3, Int((4 * palette.scale).rounded()))
        return GeometryReader { proxy in
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
    }

    /// The play triangle or pause bars, sized to the caption height.
    func playState(playing: Bool) -> some View {
        let side = max(8, Int(palette.captionSize.rounded()))
        return Group {
            if playing {
                PlayGlyph().fill(palette.secondary)
            } else {
                PauseGlyph().fill(palette.secondary)
            }
        }
        .frame(width: side, height: side)
    }
}
