// LifeCounterLayout.swift — Tile layout: tappable +/− flanking a big centred total.

public extension WidgetLayout {
    /// A big centred value with a tappable `+` above and `−` below, flanked by a
    /// reset glyph on the left and the in-progress change on the right, the value
    /// itself also tappable to reset. Built for `LifeCounterWidget`.
    ///
    /// The glyph and the value raise the same `life.reset`: tapping the number has
    /// always reset the seat, but nothing said so, so the glyph is the visible
    /// affordance for a gesture that already existed.
    ///
    /// Holding `+`/`−` moves by ten rather than one — the hold action is a separate
    /// name, so the widget decides the step size and the layout just says "this
    /// region also responds to a hold".
    ///
    /// **Every node here is unconditional; only the STRINGS vary.** That is a
    /// correctness requirement on GTK, not a style choice. Adding or removing a child
    /// mid-press rebuilds the widgets below it, and GTK cancels the gesture on the
    /// one the finger is holding — its `released` never arrives, so `HoldGate`'s
    /// auto-repeat never stops. Measured on the panel: a conditional reset glyph
    /// sits above `−`, so a hold on `−` that pushed life off 40 made the glyph
    /// appear, rebuilt `−`, and ran the seat down to −80 after the finger had
    /// lifted. A hold on `+` never showed it — `+` is above the insertion point, so
    /// it is never rebuilt. Absent children are therefore drawn as empty text.
    ///
    /// The action names are the widget's own (`LifeCounterWidget.Action`), spelled
    /// literally here because layouts live in the framework and know nothing about
    /// any particular widget — the pairing is by string, which is what lets a
    /// layout stay pure data.
    static let lifeCounter = Self(id: "lifeCounter") { content in
        /// Minimum edge of a small control's hit area, in reference-canvas units.
        /// 44 lands near 66px on the 1.5x panel — about 11mm, a comfortable finger.
        let touch = 44.0
        /// Height of the `+`/`−` strips — a quarter of this tile on the panel.
        let band = 55.0

        // Reset glyph, total, in-progress change — one row, the two flankers always
        // present and empty when they have nothing to say.
        //
        // Flanking rather than stacking is what makes "always present" free. An empty
        // label is zero-WIDTH but still a full line HIGH, so a reserved slot costs
        // nothing here and cost a permanently blank line when the glyph sat under the
        // total. It also self-centres: the two gaps sit either side of the number, so
        // with both flankers empty the number lands dead centre anyway.
        //
        // `.secondary` for both flankers. `.badge` (what the turn tile uses for its
        // RESET) is caption-size — a ~4mm target on this panel, too small for a
        // finger — and `.primary`, the size the `+`/`−` use, would out-weigh the
        // total it belongs to. Matching sizes left and right also keeps the number
        // from drifting far off centre when only one of them is showing.
        // The reset glyph gets a finger-sized region rather than a glyph-sized one —
        // `.secondary` ink is about 4mm on this panel. The change readout opposite it
        // is given the SAME minimum so the two slots stay symmetric and the total
        // still lands dead centre when both are empty; it isn't tappable, the width
        // is purely for balance.
        let total: WidgetView = .stack(.horizontal, spacing: 8, [
            .tappable(
                action: "life.reset", hold: nil,
                .touchTarget(touch, .text(content.accessoryText ?? "", role: .secondary))
            ),
            .tappable(action: "life.reset", hold: nil, .text(content.primaryText, role: .hero)),
            .touchTarget(touch, .text(content.secondaryText ?? "", role: .secondary)),
        ])

        // `+` and `−` are BANDS, not glyphs: each claims the top and bottom quarter of
        // the tile, so anywhere in that strip counts. `band` is a MINIMUM height, and
        // the spacers either side of the total still do the centring — letting the two
        // bands grow greedily instead pulled the total 30px off centre, because this
        // backend does not split leftover space evenly between greedy siblings.
        //
        // At 1.5x on the panel this puts each band at ~82px against a ~330px tile:
        // a quarter, and it lands the glyphs within ~2px of where they have always
        // been drawn.
        return .stack(.vertical, spacing: 0, [
            .tappable(
                action: "life.increment", hold: "life.incrementTen",
                .touchBand(band, .centered([.text("+", role: .primary)]))
            ),
            .spacer,
            .centered([total]),
            .spacer,
            .tappable(
                action: "life.decrement", hold: "life.decrementTen",
                .touchBand(band, .centered([.text("−", role: .primary)]))
            ),
        ])
    }
}
