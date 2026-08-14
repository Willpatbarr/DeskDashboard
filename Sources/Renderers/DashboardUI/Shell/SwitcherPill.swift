// SwitcherPill.swift — The header's arrangement switcher: a pill whose highlight glides between slots.

import SwiftCrossUI

/// Animation state for the pill's sliding highlight, owned by `SwitcherPill`
/// rather than by `DashboardModel`.
///
/// That ownership is the whole point: a frame publishes a change on *this*
/// object, so SwiftCrossUI re-renders the pill's subtree instead of the entire
/// dashboard. Driving the same animation from the shared model meant every one of
/// the ~12 frames re-laid-out all five tiles, which the Pi's GTK backend could
/// not keep up with — the slide was visibly choppy on the panel while measuring
/// fine on AppKit.
///
/// No `import Foundation` here on purpose: Foundation's `ObservableObject` /
/// `Published` collide with SwiftCrossUI's. The `Timer` lives in `FrameTicker`.
final class PillAnimator: ObservableObject {
    /// Fractional segment index the highlight is drawn at.
    @Published private(set) var position: Double = 0

    /// The index most recently animated toward, so the view can tell a new
    /// selection from a re-render of the same one.
    private(set) var target: Double = 0

    private let ticker = FrameTicker()
    private var frame = 0
    private var frames = 1
    private var from: Double = 0

    /// Frame cadence, in seconds. Tunable at runtime with `DD_UI_FRAME_MS` so a
    /// display's real budget can be found without a rebuild (a Pi build is
    /// minutes); `DD_UI_LOG=1` makes `FrameTicker` report the cadence it actually
    /// achieved per slide, which is how the default below was chosen rather than
    /// guessed.
    ///
    /// History: this sat at 50ms (~20fps) because an early version drove the
    /// animation from `DashboardModel`, where every frame re-laid-out all five
    /// tiles (~100 re-layouts per slide) and 16ms produced ragged, dropped
    /// frames. With the animator owned locally (see this type's doc comment) a
    /// frame is a pill-only redraw, so the budget is far larger than that
    /// measurement implied. `DD_UI_SLIDE_MS=0` opts out of animating entirely.
    static var frameInterval: Double { DashboardLaunch.frameSeconds }

    /// Slides to `index` over `milliseconds`. Zero (or less) jumps instantly,
    /// which is the escape hatch when a display can't animate acceptably.
    func slide(to index: Int, milliseconds: Double) {
        let destination = Double(index)
        guard destination != target else { return }

        target = destination

        guard milliseconds > 0 else {
            ticker.stop()
            position = destination
            return
        }

        from = position
        frame = 0
        frames = max(1, Int((milliseconds / 1000 / Self.frameInterval).rounded()))

        ticker.start(interval: Self.frameInterval) { [weak self] in
            self?.advance()
        }
    }

    /// One frame, eased so it accelerates out of the old slot and decelerates
    /// into the new one.
    ///
    /// Ease-in-**out** rather than the ease-out this used to have: with a
    /// travelling highlight, starting at full speed reads as a jump, because the
    /// first frame already displaces the pill by the largest step it will ever
    /// take. Smoothstep spends its big steps in the middle, where the eye tracks
    /// motion instead of edges.
    private func advance() {
        frame += 1
        let t = min(1, Double(frame) / Double(frames))
        let eased = t * t * (3 - 2 * t)

        position = from + (target - from) * eased

        if t >= 1 {
            ticker.stop()
            position = target
        }
    }
}

/// The travelling highlight: a rounded rect drawn at an animated offset inside
/// one full-width widget.
///
/// This is how the slide avoids the **ghost trails** that killed the previous
/// attempt. That version moved a highlight *view* across the row by animating
/// its leading padding, and GTK never repainted the region the view vacated, so
/// old circles stayed on screen. Here the widget spans the whole row and never
/// moves or resizes — only the path inside it changes — so every frame repaints
/// the entire region it owns. Nothing can be left behind.
struct PillHighlight: Shape {
    /// Distance from the row's leading edge to the highlight, in points.
    let offset: Double
    let width: Double
    let cornerRadius: Double

    nonisolated func path(in bounds: Path.Rect) -> Path {
        Path().addSubpath(
            RoundedRectangle(cornerRadius: cornerRadius).path(
                in: Path.Rect(
                    x: bounds.x + offset,
                    y: bounds.y,
                    width: width,
                    height: bounds.height
                )
            )
        )
    }
}

/// The segmented preview switcher: a row of fixed slots whose *fill* travels
/// between them.
///
/// Nothing in here moves. An earlier version slid one highlight view across the
/// row by animating its leading padding, and on the Pi's GTK backend that left
/// **ghost circles** at previous positions — the compositor never repainted the
/// region the overlay vacated. Instead each slot owns its own background and the
/// animation just varies each slot's fill opacity by distance from the animated
/// position, so the only thing changing per frame is a colour on a widget that
/// therefore redraws itself. Reads as a travelling glow; cannot smear.
///
/// Geometry is passed in and is deliberately **independent of the selected
/// preview's theme**: previews carry their own typography (caption 13/14/18), so
/// deriving slot sizes from the current palette made the pill change size every
/// time you switched layouts.
///
/// Slots show each preview's SHORT label. They once showed bare numbers: with
/// nine previews, uniform slots sized to the widest word ("Compact") ran
/// ~1320px and overflowed the Pi's 1920px row. Five short labels fit fine —
/// but keep labels to ~5 characters, and if the preview count grows past ~7,
/// numbers may need to come back (`segmentWidth` in `DashboardRootView` is
/// where the math lives).
struct SwitcherPill: View {
    let palette: ThemeToSCUIPalette
    /// One short label per slot.
    let labels: [String]
    let selected: Int
    /// Slot geometry, computed by the parent so it can also reserve the row's
    /// height (an under-reserved header clipped the pill's bottom edge).
    let slotWidth: Int
    let slotHeight: Int
    let trackInset: Int
    /// Digit size, from the stable chrome palette rather than the preview's, so
    /// the pill doesn't resize when a preview with different typography is picked.
    let fontSize: Double
    /// Total slide duration; 0 disables the animation.
    let slideMilliseconds: Double
    /// The track's fill. Defaults to the theme surface, which is what reads as a
    /// pill against the dashboard's background — but a pill sitting ON the accent
    /// (the tile editor) needs a dark track instead, or it vanishes into its own
    /// backdrop.
    var trackColor: Color? = nil
    let onSelect: (Int) -> Void

    @State private var animator = PillAnimator()

    /// How far to lift a digit inside its slot, cancelling the descender space in
    /// the label's box that digits never use.
    private var opticalRise: Int { max(1, Int((fontSize * 0.22).rounded())) }

    /// Height of the whole control, so the parent can reserve exactly this much.
    static func height(slotHeight: Int, trackInset: Int) -> Int {
        slotHeight + trackInset * 2
    }

    /// How opaque a pill label is — shared with `EditPill` so every word in the
    /// header carries the same weight.
    ///
    /// Deliberately NOT `palette.fillOpacity`, and deliberately not conditional on
    /// the wallpaper. The fills thin to 0.55 over a photo, which a caption-sized
    /// label cannot survive; this is a slight softening that lets the chrome's text
    /// settle into its backdrop instead of sitting on top of it at full strength,
    /// and it holds on a flat background too.
    static let labelOpacity = 0.85

    /// Opacity for a lit fill — this pill's travelling highlight and `EditPill`'s
    /// on state — given the palette it's drawn from.
    ///
    /// A notch thinner than the panels' `fillOpacity` rather than equal to it,
    /// because a highlight is the only fill here that stacks: it sits on the pill's
    /// own translucent track, so at the panels' alpha it composites to more coverage
    /// than a panel does and reads heavier than everything around it.
    ///
    /// Untouched when `fillOpacity` is 1 — off a wallpaper there is nothing behind
    /// the header to see through, and a lit slot that can't quite commit to being
    /// lit just looks unfinished.
    static func fillOpacity(_ palette: ThemeToSCUIPalette) -> Double {
        palette.fillOpacity < 1 ? palette.fillOpacity * 0.8 : 1
    }

    var body: some View {
        // Idempotent: the animator ignores a target it is already heading to, so
        // both taps and programmatic selection changes animate through one path.
        animator.slide(to: selected, milliseconds: slideMilliseconds)

        let pillHeight = Self.height(slotHeight: slotHeight, trackInset: trackInset)

        let rowWidth = Double(slotWidth * max(1, labels.count))

        return ZStack {
            // One travelling highlight behind every label, instead of each slot
            // cross-fading its own fill in and out. The crossfade could never
            // read as motion — the highlight was only ever *at* a slot, so a
            // slide was a row of pills blinking in sequence no matter how many
            // frames it got. A path redrawn at a fractional offset genuinely
            // glides, and does it without moving a widget (see `PillHighlight`).
            PillHighlight(
                offset: animator.position * Double(slotWidth),
                width: Double(slotWidth),
                cornerRadius: Double(max(0, slotHeight / 2 - 1))
            )
            // Thinned along with the panels (see `fillOpacity(_:)`), so over a
            // wallpaper the selected slot is glass like everything else rather
            // than the one solid shape on the board. Off a wallpaper this is the
            // flat accent it always was.
            .fill(palette.accent.opacity(Self.fillOpacity(palette)))
            .frame(width: rowWidth, height: Double(slotHeight))

            HStack(spacing: 0) {
                ForEach(Array(0..<labels.count), id: \.self) { index in
                    slot(index)
                }
            }
            .frame(width: rowWidth, height: Double(slotHeight))
        }
        // Every one of these three modifiers is load-bearing for *visibility*,
        // established by screenshotting each variation on the panel:
        //   - drop `.frame(height:)`  -> the row collapses, taps stop landing
        //   - drop `.background(...)` -> the whole control disappears (an HStack
        //     with no background gets no widget of its own here)
        //   - drop `.cornerRadius(...)` -> likewise disappears
        // This radius does NOT clip the track on the GTK backend (corner radius
        // only clips when applied by the PARENT) — the visible pill shape comes
        // from `DashboardRootView.previewBar` applying `.pillCorners` at the
        // call site, same pattern as `tileCorners`. This one stays because
        // dropping it hides the control.
        .frame(height: Double(slotHeight))
        .padding(trackInset)
        .background(trackColor ?? palette.surface)
        .cornerRadius(max(0, min(pillHeight / 2 - 1, slotHeight / 2)))
    }

    private func slot(_ index: Int) -> some View {
        // How covered this slot is by the travelling highlight, for the label's
        // colour only — the highlight itself is drawn once, behind the whole row.
        let distance = abs(Double(index) - animator.position)
        let covered = max(0, min(1, 1 - distance)) > 0.5

        return Text(labels[index])
            .font(.system(size: fontSize, weight: .semibold))
            // Flip the label to the dark background colour once the highlight is
            // mostly over it, so it stays legible against the accent.
            .foregroundColor(
                (covered ? palette.background : palette.accent)
                    .opacity(Self.labelOpacity)
            )
            // A wrapped label grows the header's height, which is what pushed
            // the tiles off-screen before. Truncate instead, always.
            .lineLimit(1)
            .frame(width: Double(slotWidth), height: Double(slotHeight))
            // Labels render ~4.5px low in their box (it reserves descender space
            // these labels barely use — measured on the panel). The negative/
            // positive pair lifts the ink without changing the slot height.
            .padding(.top, -opticalRise)
            .padding(.bottom, opticalRise)
            .onTapGesture {
                onSelect(index)
            }
    }
}
