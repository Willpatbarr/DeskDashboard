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

/// The segmented preview switcher: a single sliding highlight behind a row of
/// equal-width slots.
///
/// Equal widths are a prerequisite for the slide — slots used to size to their
/// text, so a slot changing between a digit and a word would have moved *and*
/// resized the highlight mid-flight while the whole row reflowed on every tap.
///
/// Unselected slots show their number; only the selected one shows its name. Nine
/// word labels at 1.5× wrapped onto two lines on the Pi's 1920×440 panel
/// ("Clo-ck", "M-TG") and inflated the header until the tiles fell off the bottom.
struct PreviewPill: View {
    let palette: ThemePalette
    let labels: [String]
    let selected: Int
    /// Slot geometry, computed by the parent so it can also reserve the row's
    /// height (an under-reserved header clipped the pill's bottom edge).
    let slotWidth: Int
    let slotHeight: Int
    let trackInset: Int
    /// Total slide duration; 0 disables the animation.
    let slideMilliseconds: Double
    let onSelect: (Int) -> Void

    @State private var animator = PillAnimator()

    /// Height of the whole control, so the parent can reserve exactly this much.
    static func height(slotHeight: Int, trackInset: Int) -> Int {
        slotHeight + trackInset * 2
    }

    var body: some View {
        // Starting a slide from `body` looks unusual, but it's idempotent (the
        // animator ignores a target it's already heading to) and it means both
        // taps and programmatic selection changes animate through one path.
        animator.slide(to: selected, milliseconds: slideMilliseconds)

        let pillHeight = Self.height(slotHeight: slotHeight, trackInset: trackInset)

        return ZStack(alignment: .leading) {
            palette.accent
                .frame(width: slotWidth, height: slotHeight)
                .cornerRadius(slotHeight / 2)
                .padding(.leading, Int((animator.position * Double(slotWidth)).rounded()))

            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { item in
                    slot(item.offset, label: item.element)
                }
            }
        }
        .padding(trackInset)
        .background(palette.surface)
        // Kept a pixel under half the height: the backends set a literal
        // `cornerRadius` with `clipsToBounds` and don't clamp it, so a radius at
        // or over half the box eats the edge (see the 999-radius gotcha).
        .cornerRadius(max(0, pillHeight / 2 - 1))
    }

    private func slot(_ index: Int, label: String) -> some View {
        let isSelected = index == selected
        return Text(isSelected ? label : "\(index + 1)")
            .font(.system(size: palette.captionSize, weight: .semibold))
            .foregroundColor(isSelected ? palette.background : palette.accent)
            // A wrapped label grows the header's height, which is what pushed the
            // tiles off-screen before. Truncate instead, always.
            .lineLimit(1)
            .frame(width: slotWidth, height: slotHeight)
            .onTapGesture {
                onSelect(index)
            }
    }
}
