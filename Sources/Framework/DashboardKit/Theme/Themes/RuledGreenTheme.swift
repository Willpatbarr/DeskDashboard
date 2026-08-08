// RuledGreenTheme.swift — Theme: flat greens, outlined tiles, hairline rules, green chrome.

// A second take on the curated board, and the one place in this project that is
// deliberately FLAT: no background gradient and no translucent surface, so every
// colour here is the colour that lands on the panel. `GreenBoardTheme` keeps the
// gradient; this one doesn't, because the design it's copied from doesn't.
//
// The distinguishing idea is that all of a tile's chrome — its label, its rules,
// and its footer — is one green. Not three tones of one green: literally the same
// token, `chrome`, assigned to `secondary` (which `TextRole.title` resolves to),
// `mutedText` (`.caption`) and `divider`. If you change it, change it once.
//
// Values below are SAMPLED from the reference image (brightest pixel per element,
// since antialiasing only ever darkens ink), not eyeballed.

public extension ThemeColors {
    /// Flat deep green with outlined tiles and a single green for all tile chrome.
    static let ruledGreen: Self = {
        // The one green: labels, hairlines and footers all take this.
        //
        // Sampled from the labels and captions, which measured #95CF98 and #9CD09D
        // — the same colour either side of antialiasing. The reference draws its
        // RULES far dimmer than its text (#31543F), so this is a deliberate
        // departure from it: one token for all tile chrome was the ask, and the
        // text colour is the one worth matching. Dim the rules by giving `divider`
        // #31543F if that ever reads too strong.
        let chrome = "#9CD09D"
        return Self(
            // Much darker than the reference on purpose, and this is NOT a
            // mismatch to go and "fix". Sampled, the reference's background is a
            // uniform #0A2218 and the panel reproduced it exactly — verified by
            // profiling both images down two columns. It still read too light in
            // the room, because the Pi's display is not colour-accurate. So this is
            // authored for the PANEL, not for the file: roughly half the
            // reference's value. Judge it on the glass, not against the PNG.
            background: "#05110C",
            // Opaque, not the translucent panel the gradient themes use — there is
            // no gradient underneath for it to pick anything up from.
            //
            // NB this token also paints the switcher pill's track, so it is not
            // purely a tile colour; `accent` (the pill's highlight and label) is
            // left alone deliberately.
            surface: "#132E23",
            primary: "#FFFFFF",
            secondary: chrome,
            accent: "#8FD79A",
            text: "#FFFFFF",
            mutedText: chrome,
            // Flat: no stops, so the renderer paints `background` directly.
            backgroundGradient: [],
            divider: chrome,
            // #365D47, not the #274736 the reference measures, ON PURPOSE. A 1px
            // stroke is antialiased and only ~68% covers its pixel, so it blends
            // with whatever is behind it: authoring #274736 rendered #1E3B2D,
            // visibly fainter than the reference. This is the value that RENDERS
            // #274736 over THIS background — it is derived from it, so re-derive it
            // (rendered = 0.68*border + 0.32*background) if either changes.
            border: "#37604A"
        )
    }()
}

public extension ThemeTypography {
    /// `airyLegible` with a smaller caption size, which is what `TextRole.title`
    /// and `.caption` both resolve to — so this quiets a tile's label and its
    /// footer together, and only those. Values and supporting lines are untouched.
    static let airyRuled = Self(
        fontFamily: "system-ui",
        headingSize: 46,
        bodySize: 24,
        captionSize: 13,
        headingWeight: 100,
        bodyWeight: 300
    )
}

public extension ThemeShape {
    /// `rounded` with a visible hairline outline.
    static let ruled = Self(
        cornerRadius: 28,
        borderWidth: 1,
        elevation: 0
    )
}

/// The ruled variant of the curated board.
public struct RuledGreenTheme: Theme, Sendable {
    public let name = "Ruled Green"
    public var colors: ThemeColors { .ruledGreen }
    public var typography: ThemeTypography { .airyRuled }
    public var shape: ThemeShape { .ruled }

    public init() {}
}
