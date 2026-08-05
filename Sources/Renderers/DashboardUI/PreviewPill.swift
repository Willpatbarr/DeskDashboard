import SwiftCrossUI

/// Animation state for the pill's sliding highlight, owned by `PreviewPill`
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

    /// Frame cadence, deliberately slow at 50ms (~20fps).
    ///
    /// Measured: SwiftCrossUI re-renders the **entire** view graph on any state
    /// change — an 8-frame slide triggered ~100 tile re-layouts — so a frame costs
    /// far more than a pill redraw should. Asking for frames the GTK backend can't
    /// finish is precisely what reads as choppy, and requesting 16ms just produced
    /// dropped frames at uneven spacing. Few, evenly-paced steps look better than
    /// many ragged ones. `DD_UI_SLIDE_MS=0` opts out entirely.
    static let frameInterval = 0.05

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

    /// One frame, eased out (cubic) so it decelerates into place.
    private func advance() {
        frame += 1
        let t = min(1, Double(frame) / Double(frames))
        let remaining = 1 - t
        let eased = 1 - remaining * remaining * remaining

        position = from + (target - from) * eased

        if t >= 1 {
            ticker.stop()
            position = target
        }
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
/// Every slot shows just its number. Sizing nine uniform slots to the widest word
/// label ("Compact") made the control ~1320px, which overran the Pi's 1920px row;
/// the selected preview's name is spelled out in the header line anyway.
struct PreviewPill: View {
    let palette: ThemePalette
    /// How many slots to draw.
    let count: Int
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
    let onSelect: (Int) -> Void

    @State private var animator = PillAnimator()

    /// How far to lift a digit inside its slot, cancelling the descender space in
    /// the label's box that digits never use.
    private var opticalRise: Int { max(1, Int((fontSize * 0.22).rounded())) }

    /// Height of the whole control, so the parent can reserve exactly this much.
    static func height(slotHeight: Int, trackInset: Int) -> Int {
        slotHeight + trackInset * 2
    }

    var body: some View {
        // Idempotent: the animator ignores a target it is already heading to, so
        // both taps and programmatic selection changes animate through one path.
        animator.slide(to: selected, milliseconds: slideMilliseconds)

        let pillHeight = Self.height(slotHeight: slotHeight, trackInset: trackInset)

        return HStack(spacing: 0) {
            ForEach(Array(0..<count), id: \.self) { index in
                slot(index)
            }
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
        .background(palette.surface)
        .cornerRadius(max(0, min(pillHeight / 2 - 1, slotHeight / 2)))
    }

    private func slot(_ index: Int) -> some View {
        // 1 when the travelling fill is centred here, 0 once it's a slot away, so
        // mid-slide two neighbours share it and the glow appears to move.
        let distance = abs(Double(index) - animator.position)
        let fill = max(0, min(1, 1 - distance))

        // The fill is its OWN exactly-slot-sized layer underneath the digit, not
        // the digit's background: painted around the padded label it inherited
        // the label's box (~7px taller than the slot, since a label's box always
        // exceeds its font size), and the track clipped the bottom cap off the
        // highlight — measured on the panel: the top of the circle tapered over
        // 5 rows, the bottom was cut after 3.
        return ZStack {
            HStack(spacing: 0) {}
                .frame(width: slotWidth, height: slotHeight)
                .background(palette.accent.opacity(fill))
                .cornerRadius(max(0, slotHeight / 2 - 1))
            Text("\(index + 1)")
                .font(.system(size: fontSize, weight: .semibold))
                // Flip the digit to the dark background colour once the fill is
                // mostly over it, so it stays legible against the accent.
                .foregroundColor(fill > 0.5 ? palette.background : palette.accent)
                // A wrapped label grows the header's height, which is what pushed
                // the tiles off-screen before. Truncate instead, always.
                .lineLimit(1)
                .frame(width: Double(slotWidth), height: Double(slotHeight))
                // Digits render ~4.5px low in their box (it reserves descender
                // space digits never use — measured on the panel). The negative/
                // positive pair lifts the ink without changing the slot height.
                .padding(.top, -opticalRise)
                .padding(.bottom, opticalRise)
        }
        .onTapGesture {
            onSelect(index)
        }
    }
}
