// EditPill.swift — The header's Edit toggle: one switcher slot that lights when on.

import SwiftCrossUI

/// A single-slot pill built to match `SwitcherPill` exactly: same track inset,
/// same slot geometry, same optical rise on the label. The only difference is
/// that it has nowhere to slide to — its fill is either the accent (on) or the
/// track's own surface (off).
///
/// Geometry is passed in from the parent for the same reason `SwitcherPill` takes
/// it: it must come from the stable chrome palette, not the selected preview's,
/// or the button resizes every time you switch layouts.
///
/// Like `SwitcherPill`, the `.frame` / `.background` / `.cornerRadius` trio at the
/// bottom is load-bearing for visibility on the GTK backend — dropping any of
/// them makes the control disappear. The *visible* pill shape still comes from
/// the parent applying `.cornerRadius`, since a corner radius only clips a
/// composited background when the parent sets it.
struct EditPill: View {
    let palette: ThemeToSCUIPalette
    let label: String
    let isOn: Bool
    let slotWidth: Int
    let slotHeight: Int
    let trackInset: Int
    let fontSize: Double
    let onTap: () -> Void

    private var opticalRise: Int { max(1, Int((fontSize * 0.22).rounded())) }

    var body: some View {
        let pillHeight = SwitcherPill.height(slotHeight: slotHeight, trackInset: trackInset)

        return Text(label)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(isOn ? palette.background : palette.accent)
            .lineLimit(1)
            .frame(width: Double(slotWidth), height: Double(slotHeight))
            .padding(.top, -opticalRise)
            .padding(.bottom, opticalRise)
            // Lit: the accent fill. Resting: the TRACK colour — i.e. exactly what
            // a switcher pill shows in the slots its highlight isn't sitting on,
            // so the Edit button reads as one of the same family of controls.
            // (Its outline is drawn by the parent and is always present, which is
            // the one thing that used to vary by theme.)
            // Clear, NOT the surface colour, when off: the track below already
            // paints it. Surface is translucent in most themes, so painting it
            // twice composited to a visibly lighter pill than the switchers'
            // (measured 42,80,62 against their 34,67,51 on the gradient board).
            .background(isOn ? palette.accent : Color.clear)
            .cornerRadius(max(0, slotHeight / 2 - 1))
            .onTapGesture { onTap() }
            .padding(trackInset)
            .background(palette.surface)
            .cornerRadius(max(0, min(pillHeight / 2 - 1, slotHeight / 2)))
    }
}
