// EditScrim.swift — The per-tile editor: a coloured veil carrying that widget's controls.

import SwiftCrossUI

/// Geometry for the editor's controls, sized from the tile's own palette rather
/// than passed in (unlike the header pills, which must stay put across preview
/// switches) — this control only exists while you're looking at it, so following
/// the tile's type scale is what keeps it proportional in a short tile and a tall
/// one alike.
///
/// Free functions rather than properties on a view type because the editor is
/// built INLINE in the modifier below; see there for why it can't be its own View.
private func editFontSize(_ palette: ThemeToSCUIPalette) -> Double {
    // A notch under the tile's caption size: this is chrome sitting *on* the
    // widget, so it shouldn't compete with the widget's own labels.
    palette.captionSize * 0.9
}

private func editSlotHeight(_ palette: ThemeToSCUIPalette) -> Int {
    Int(editFontSize(palette).rounded()) + max(4, Int((8 * palette.verticalScale).rounded())) * 2
}

/// Sized to "Center", the widest of the three labels, by the same ~0.62em estimate
/// the header pills use (no text measurement exists on this backend).
private func editSlotWidth(_ palette: ThemeToSCUIPalette) -> Int {
    Int((6 * editFontSize(palette) * 0.62).rounded()) + Int((10 * palette.scale).rounded()) * 2
}

private func editTrackInset(_ palette: ThemeToSCUIPalette) -> Int {
    max(3, Int((5 * palette.verticalScale).rounded()))
}

extension View {
    /// Swaps a tile's contents for its editor while edit mode is on, and does
    /// nothing at all otherwise.
    ///
    /// Branching rather than keeping a transparent overlay around year-round: an
    /// overlay is a real widget on the GTK backend and would swallow the tile's
    /// taps even at zero opacity. Toggling edit mode re-renders the whole tree
    /// regardless, so the structure change costs nothing here.
    ///
    /// The editor is built INLINE here rather than extracted into a `View` struct.
    /// It was a struct first and rendered as *nothing at all* on the panel —
    /// the same trap `TileView` and `tileCorners` document from the other side:
    /// composited chrome (a background, a corner radius) declared inside a child
    /// view's own body doesn't take on this backend. Keep it inline.
    ///
    /// Applied *inside* the tile's corner rounding at the call site, so the veil
    /// is clipped to the tile's shape instead of squaring off its corners.
    @ViewBuilder func editScrim(
        _ palette: ThemeToSCUIPalette,
        active: Bool,
        alignment: TileAlignment,
        onSelectAlignment: @escaping (Int) -> Void
    ) -> some View {
        if active {
            let cases = TileAlignment.allCases

            overlay {
                // Measured against the TILE, not the palette alone: a 1fr temp
                // column on the focus board is ~245px wide, and a pill sized
                // purely from the type scale (~300px) hung off both edges of it.
                GeometryReader { proxy in
                    // 0×0 is an early pass and a non-finite width is a probe pass
                    // (a nested GeometryReader reports infinity here) — treat both
                    // as "no constraint" rather than trapping on `Int(inf)`.
                    let measured = proxy.size.width
                    let available = measured.isFinite && measured > 1 ? measured : .infinity

                    let trackInset = editTrackInset(palette)
                    let wanted = editSlotWidth(palette)
                    // Three slots plus the track's insets have to fit, with a
                    // little margin so the pill doesn't touch the tile's edges.
                    let room = (available - Double(trackInset * 2) - 12) / 3
                    let slotWidth = max(24, Int(min(Double(wanted), room).rounded()))

                    // Shrink the type with the slot rather than letting the
                    // labels truncate — "Cen…" is useless as a control.
                    let squeeze = min(1, Double(slotWidth) / Double(max(1, wanted)))
                    let font = editFontSize(palette) * squeeze
                    let slotHeight = max(
                        14,
                        Int(Double(editSlotHeight(palette)) * squeeze)
                    )
                    let pillHeight = SwitcherPill.height(
                        slotHeight: slotHeight,
                        trackInset: trackInset
                    )

                // The veil is its own ZStack layer rather than the control
                // stack's `.background`, for the same reason the pill's
                // highlight is a shape: a `Color` layer paints reliably here,
                // whereas a background behind a greedy stack had no size to
                // paint into.
                ZStack {
                    palette.accent
                        .opacity(0.85)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    VStack(
                        alignment: .center,
                        // Measured on the panel: at ~4px the subtitle's box sat
                        // right on the pill's top edge, reading as one blob.
                        spacing: max(6, Int((9 * palette.verticalScale).rounded()))
                    ) {
                        // The subtitle: deliberately tiny and quiet. It names the
                        // control under it, and more of these will stack up here.
                        Text("Alignment")
                            .font(.system(size: font * 0.72, weight: .semibold))
                            .foregroundColor(palette.background)
                            .lineLimit(1)

                        SwitcherPill(
                            palette: palette,
                            labels: cases.map(\.label),
                            selected: cases.firstIndex(of: alignment) ?? 0,
                            slotWidth: slotWidth,
                            slotHeight: slotHeight,
                            trackInset: trackInset,
                            fontSize: font,
                            slideMilliseconds: DashboardLaunch.slideMilliseconds,
                            trackColor: palette.background,
                            onSelect: onSelectAlignment
                        )
                        // Applied by the parent, as always on this backend — a
                        // pill that rounds itself renders square.
                        .cornerRadius(max(0, pillHeight / 2 - 1))
                    }
                }
                }
            }
        } else {
            self
        }
    }
}
