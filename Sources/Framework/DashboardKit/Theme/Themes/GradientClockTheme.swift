// GradientClockTheme.swift — Theme: deep-green gradient with thin numerals, used by the MTG screen.

// The gradient-clock look, and the tokens it introduces.
//
// `ThemeColors.gradientClock` and `ThemeShape.rounded` are declared here and
// reused by `GreenBoardTheme` — one palette, two type scales. Edit them here and
// both themes move together; that's intentional, and the reason they aren't
// duplicated per file.

public extension ThemeColors {
    /// Deep-green gradient with a mint accent and translucent panels — white
    /// numerals, green labels.
    ///
    /// The panel surface is a *lighter* translucent green, not a darker one. It
    /// used to be `#05120B47` — 28% alpha of a near-black green — layered over
    /// this dark gradient, which measured 1–2/255 away from the background on the
    /// panel (tile `(9,22,15)` vs background `(11,23,17)`), so tiles had no
    /// perceptible edge or corner and read as vague blocks. A lighter
    /// translucent fill is also closer to the frosted-panel look this is modeled
    /// on. Don't darken it again without re-measuring.
    static let gradientClock = Self(
        background: "#0F2018",
        surface: "#3C6E554D",
        primary: "#FFFFFF",
        secondary: "#8FD79A",
        accent: "#8FD79A",
        text: "#FFFFFF",
        mutedText: "#6F9E78",
        backgroundGradient: ["#193326", "#0F2018", "#08110D"],
        // Authored brighter than it draws: a 1px stroke is antialiased and only
        // ~68% covers its pixel, so it blends with what is behind it. This is the
        // value that renders a ~#2F5240 hairline over this gradient's mid stop.
        // See `RuledGreenTheme`, where the same compensation is derived in full.
        border: "#3E6A53"
    )
}

public extension ThemeTypography {
    /// Large, thin numerals with light labels — the gradient-clock aesthetic.
    ///
    /// The weight-100 heading only renders as thin because of the GTK weight
    /// mapping fix in the renderer's `Font.Weight(cssWeight:)`; if headings ever
    /// come back looking merely Light, suspect that mapping rather than this.
    static let airy = Self(
        fontFamily: "system-ui",
        headingSize: 44,
        bodySize: 18,
        captionSize: 14,
        headingWeight: 100,
        bodyWeight: 300
    )
}

public extension ThemeShape {
    /// Soft, pill-adjacent corners for the gradient-clock panels.
    static let rounded = Self(
        cornerRadius: 28,
        borderWidth: 1,
        elevation: 2
    )
}

/// Gradient-clock colours at the `airy` type scale. Used by the MTG screen.
public struct GradientClockTheme: Theme, Sendable {
    public let name = "Gradient"
    public var colors: ThemeColors { .gradientClock }
    public var typography: ThemeTypography { .airy }
    public var shape: ThemeShape { .rounded }

    public init() {}
}
