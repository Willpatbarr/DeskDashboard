// SlideStage.swift — Fullscreen transition: two skeleton boards sliding as one animated shape.

import DashboardKit
import SwiftCrossUI

/// Animation state for the screen slide, owned by `SlideStage` rather than
/// `DashboardModel` — the same ownership rule as `PillAnimator`: a frame
/// publishes on THIS object, so only the stage's subtree re-renders per frame
/// instead of the whole dashboard.
///
/// No `import Foundation` here on purpose (same collision as the pill); the
/// `Timer` lives in `FrameTicker`.
final class SlideAnimator: ObservableObject {
    /// 0 → 1 sweep progress, smoothstep-eased.
    @Published private(set) var progress: Double = 0

    /// Which transition this run belongs to, so a re-render of the stage during
    /// an active sweep doesn't restart it (the same guard `PillAnimator` keys on
    /// its target index).
    private(set) var runKey: String?

    private let ticker = FrameTicker()
    private var frame = 0
    private var frames = 1
    private var onFinished: (() -> Void)?

    /// Starts the sweep for transition `key`; calling again with the same key is
    /// a no-op re-render. Zero duration completes immediately.
    func run(key: String, milliseconds: Double, onFinished: @escaping () -> Void) {
        guard key != runKey else { return }
        runKey = key
        self.onFinished = onFinished
        progress = 0

        guard milliseconds > 0 else {
            finish()
            return
        }
        frame = 0
        frames = max(1, Int((milliseconds / 1000 / DashboardLaunch.frameSeconds).rounded()))
        ticker.start(interval: DashboardLaunch.frameSeconds) { [weak self] in
            self?.advance()
        }
    }

    private func advance() {
        frame += 1
        let t = min(1, Double(frame) / Double(frames))
        // Smoothstep, matching the pill: big steps mid-travel where the eye
        // tracks motion, gentle at both ends where it tracks edges.
        progress = t * t * (3 - 2 * t)
        if t >= 1 { finish() }
    }

    private func finish() {
        ticker.stop()
        progress = 1
        let done = onFinished
        onFinished = nil
        done?()
    }
}

/// Every skeleton tile of both boards, drawn as ONE full-stage shape.
///
/// One shape, not per-tile views, because of the GTK ghost-trail rule
/// (`PillHighlight`'s doc): a view that MOVES leaves its old pixels behind,
/// but a stationary full-region shape whose internal path changes repaints
/// everything it owns every frame. The stage spans the whole viewport and
/// never moves; only the rects inside it do.
struct SkeletonSweep: Shape {
    let rects: [Path.Rect]
    let cornerRadius: Double

    nonisolated func path(in bounds: Path.Rect) -> Path {
        var path = Path()
        // Rects are stage-relative; anchor them to the bounds origin the same
        // way `PillHighlight` does — the backend does not guarantee (0,0).
        for rect in rects where rect.width > 1 {
            path = path.addSubpath(
                RoundedRectangle(cornerRadius: cornerRadius).path(
                    in: Path.Rect(
                        x: bounds.x + rect.x,
                        y: bounds.y + rect.y,
                        width: rect.width,
                        height: rect.height
                    )
                )
            )
        }
        return path
    }
}

/// The transition screen: the outgoing board's skeleton sliding off one edge
/// while the incoming board's slides in from the other. Skeletons are one
/// rounded rect per board column — cheap enough that a 50fps sweep re-lays-out
/// almost nothing (the documented budget that full tiles blow).
///
/// When the sweep completes the model swaps the real arrangement in
/// (`completeTransition`), so content "fills the skeletons" in a single frame.
struct SlideStage: View {
    let palette: ThemeToSCUIPalette
    let width: Double
    let height: Double
    /// Skeleton shapes: the outgoing and incoming boards' bands.
    let from: [BoardBand]
    let to: [BoardBand]
    let enteringFromRight: Bool
    /// The transition's identity (`ScreenTransition.key`).
    let transitionKey: String
    let onFinished: () -> Void

    @State private var animator = SlideAnimator()

    var body: some View {
        // Kicked from body, exactly like the pill slides on selection change —
        // `run` no-ops when the key already ran, so re-renders are safe.
        animator.run(
            key: transitionKey,
            milliseconds: DashboardLaunch.slideMilliseconds,
            onFinished: onFinished
        )

        // Direction sign for the OUTGOING surface; the incoming one trails it
        // exactly one screen-width behind.
        let sign: Double = enteringFromRight ? -1 : 1
        let travel = animator.progress * width
        let rects =
            Self.skeletonRects(for: from, width: width, height: height,
                               palette: palette, xOffset: sign * travel)
            + Self.skeletonRects(for: to, width: width, height: height,
                                 palette: palette, xOffset: sign * travel - sign * width)

        // The ZStack + `.frame` + `.background` + `.cornerRadius` ceremony is
        // load-bearing for VISIBILITY on the GTK backend, same as SwitcherPill's
        // (see its measured note): a view with no background gets no widget of
        // its own there and simply never draws. The first deploy of this stage
        // shipped a bare `.fill().frame()` and the sweep was invisible.
        return ZStack {
            SkeletonSweep(rects: rects, cornerRadius: palette.cornerRadius)
                // NOT `palette.surface`: the ruled theme's tiles are outlined, its
                // surface is near-identical to its background (#132E23 on #05110C),
                // and surface-filled skeletons slid by invisibly. A thinned
                // secondary reads as ghost tiles on every theme.
                .fill(palette.secondary.opacity(0.22))
                .frame(width: width, height: height)
        }
        .frame(width: width, height: height)
        .background(palette.background)
        .cornerRadius(2)
    }

    /// One rounded rect per column, laid out from the board's band/column
    /// weights with the same margins and gaps the real board uses — so the
    /// incoming skeleton lands exactly where the real tiles will ink in.
    static func skeletonRects(
        for bands: [BoardBand],
        width: Double,
        height: Double,
        palette: ThemeToSCUIPalette,
        xOffset: Double
    ) -> [Path.Rect] {
        guard !bands.isEmpty else { return [] }

        let hMargin = Double(palette.sectionMargin)
        let vMargin = Double(palette.verticalSectionMargin)
        let colGap = Double(palette.widgetGap)
        let bandGap = Double(palette.verticalWidgetGap)

        let innerWidth = max(1, width - hMargin * 2)
        let innerHeight = max(1, height - vMargin * 2)

        var rects: [Path.Rect] = []
        let bandWeightSum = max(0.001, bands.map(\.weight).reduce(0, +))
        let bandGapTotal = bandGap * Double(max(0, bands.count - 1))
        var y = vMargin

        for band in bands {
            let bandHeight = (innerHeight - bandGapTotal) * band.weight / bandWeightSum
            let columns = band.columns
            let colWeightSum = max(0.001, columns.map(\.weight).reduce(0, +))
            let colGapTotal = colGap * Double(max(0, columns.count - 1))
            var x = hMargin + xOffset

            for column in columns {
                let colWidth = (innerWidth - colGapTotal) * column.weight / colWeightSum
                rects.append(Path.Rect(x: x, y: y, width: colWidth, height: bandHeight))
                x += colWidth + colGap
            }
            y += bandHeight + bandGap
        }
        return rects
    }
}
