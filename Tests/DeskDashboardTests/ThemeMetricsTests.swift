// ThemeMetricsTests.swift — Tests: viewport scaling, and the theme scaffold's defaults contract.

import DashboardKit
import Testing

@Test func referenceViewportResolvesToUnitScale() {
    #expect(ThemeMetrics.default.scale(for: .reference) == 1)
}

@Test func defaultBasisIsWidthOnly() {
    let metrics = ThemeMetrics.default
    #expect(metrics.basis == .width)

    // Height gets no vote: a short, wide window still scales off its width.
    // (This is the real shape of the app's window — the AppKit backend opens it
    // at ~1329×350, which under a min-of-both rule collapsed to the clamp floor.)
    #expect(metrics.scale(for: Viewport(width: 1280, height: 350)) == 1)
    #expect(metrics.scale(for: Viewport(width: 2560, height: 350)) == 2)
    #expect(metrics.scale(for: Viewport(width: 1920, height: 1080)) == 1.5)
}

@Test func fitBasisUsesTheTighterOfTheTwoDimensions() {
    let metrics = ThemeMetrics(basis: .fit)

    // Twice as wide, same height: height is the tighter fit, so no growth.
    #expect(metrics.scale(for: Viewport(width: 2560, height: 800)) == 1)
    // Both dimensions doubled: uniform 2×.
    #expect(metrics.scale(for: Viewport(width: 2560, height: 1600)) == 2)
    // A 1024×600 Pi panel: 600/800 is tighter than 1024/1280.
    #expect(metrics.scale(for: Viewport(width: 1024, height: 600)) == 0.75)
}

@Test func heightBasisUsesHeightOnly() {
    let metrics = ThemeMetrics(basis: .height)

    #expect(metrics.scale(for: Viewport(width: 400, height: 1600)) == 2)
    #expect(metrics.scale(for: Viewport(width: 4000, height: 800)) == 1)
}

@Test func scaleIsClampedAtBothEnds() {
    let metrics = ThemeMetrics(minimumScale: 0.8, maximumScale: 1.5)

    #expect(metrics.scale(for: Viewport(width: 320, height: 200)) == 0.8)
    #expect(metrics.scale(for: Viewport(width: 7680, height: 4320)) == 1.5)
}

@Test func degenerateViewportFallsBackToUnitScale() {
    #expect(ThemeMetrics.default.scale(for: Viewport(width: 0, height: 0)) == 1)
    #expect(ThemeMetrics.default.scale(for: Viewport(width: -100, height: 800)) == 1)
}

@Test func fixedMetricsNeverScale() {
    #expect(ThemeMetrics.fixed.scale(for: Viewport(width: 3840, height: 2160)) == 1)
    #expect(ThemeMetrics.fixed.scale(for: Viewport(width: 800, height: 480)) == 1)
}

@Test func themeSizesScaleTypeSpacingAndCornerRadius() {
    let theme = DarkDeskTheme()
    let sizes = theme.sizes(for: Viewport(width: 2560, height: 1600))

    #expect(sizes.scale == 2)
    #expect(sizes.typography.headingSize == theme.typography.headingSize * 2)
    #expect(sizes.typography.bodySize == theme.typography.bodySize * 2)
    #expect(sizes.typography.captionSize == theme.typography.captionSize * 2)
    #expect(sizes.spacing.widgetGap == theme.spacing.widgetGap * 2)
    #expect(sizes.spacing.tilePadding == theme.spacing.tilePadding * 2)
    #expect(sizes.spacing.sectionMargin == theme.spacing.sectionMargin * 2)
    #expect(sizes.shape.cornerRadius == theme.shape.cornerRadius * 2)
}

@Test func manualMultiplierStacksOnTopOfTheComputedScale() {
    let theme = DarkDeskTheme()
    let viewport = Viewport(width: 1920, height: 1080)   // width basis -> 1.5

    #expect(theme.sizes(for: viewport, multiplier: 2).scale == 3)
    #expect(theme.sizes(for: viewport, multiplier: 1).scale == 1.5)
    // A nonsense multiplier is ignored rather than zeroing every size.
    #expect(theme.sizes(for: viewport, multiplier: 0).scale == 1.5)
}

@Test func scalingLeavesScreenIndependentTokensAlone() {
    // `.airy` / `.rounded` are declared in `Themes/GradientClockTheme.swift`, not
    // the scaffold — reaching them from here proves a theme file's named tokens
    // stay reusable module-wide.
    let theme = DarkDeskTheme(typography: .airy, shape: .rounded)
    let sizes = theme.sizes(for: Viewport(width: 1920, height: 1200))

    // Weights, font family, hairline border and elevation read the same at any
    // size, so they pass through untouched.
    #expect(sizes.typography.fontFamily == theme.typography.fontFamily)
    #expect(sizes.typography.headingWeight == theme.typography.headingWeight)
    #expect(sizes.typography.bodyWeight == theme.typography.bodyWeight)
    #expect(sizes.shape.borderWidth == theme.shape.borderWidth)
    #expect(sizes.shape.elevation == theme.shape.elevation)
}

// MARK: - The scaffold contract

/// A theme declaring nothing but its name — the minimum the scaffold allows.
/// If this stops compiling, a token lost its default and every future theme file
/// has to restate it.
private struct BareTheme: Theme {
    let name = "Bare"
}

@Test func aThemeNeedOnlyDeclareItsName() {
    let theme = BareTheme()

    // Unstated tokens fall back to the scaffold's defaults...
    #expect(theme.typography == .default)
    #expect(theme.spacing == .default)
    #expect(theme.shape == .default)
    #expect(theme.animation == .default)
    // ...including the layout, and the baseline palette that lives with the
    // baseline theme rather than in the scaffold.
    #expect(theme.colors == .darkDesk)
    #expect(theme.defaultLayout is GridLayout)
}

@Test func themeFilesOwnTheirNamedTokensAndShareThem() {
    // Both green themes resolve to the one palette declared in
    // `GradientClockTheme.swift`; only the type scale differs.
    #expect(GreenBoardTheme().colors == GradientClockTheme().colors)
    #expect(GreenBoardTheme().shape == GradientClockTheme().shape)
    #expect(GreenBoardTheme().typography != GradientClockTheme().typography)
    #expect(GreenBoardTheme().typography == .airyLegible)
    #expect(GradientClockTheme().typography == .airy)
}

/// Pins the actual default values, not just "equals `.default`".
///
/// The `.default` tokens moved out of the scaffold into
/// `Themes/DefaultTheme.swift`; comparisons against `.default` would have passed
/// even if a number changed in the move, so these assert the numbers themselves.
/// They also protect every theme that doesn't name its own tokens — editing a
/// default silently moves all of them.
@Test func defaultThemeTokenValuesAreUnchanged() {
    let theme = DefaultTheme()

    #expect(theme.name == "Default")
    #expect(theme.typography.fontFamily == "system-ui")
    #expect(theme.typography.headingSize == 28)
    #expect(theme.typography.bodySize == 17)
    #expect(theme.typography.captionSize == 13)
    #expect(theme.typography.headingWeight == 700)
    #expect(theme.typography.bodyWeight == 500)

    #expect(theme.spacing.widgetGap == 12)
    #expect(theme.spacing.tilePadding == 16)
    #expect(theme.spacing.sectionMargin == 20)

    #expect(theme.shape.cornerRadius == 8)
    #expect(theme.shape.borderWidth == 1)
    #expect(theme.shape.elevation == 2)

    #expect(theme.animation.transitionDuration == 0.18)
    #expect(theme.animation.easing == "easeInOut")

    // The baseline palette, still owned by `DarkDeskTheme.swift`.
    #expect(theme.colors.background == "#090D14")
    #expect(theme.colors.accent == "#36C2FF")
}

@Test func defaultThemeMatchesABareConformance() {
    // Same contract, two spellings — if these ever diverge, a default moved.
    #expect(DefaultTheme().typography == BareTheme().typography)
    #expect(DefaultTheme().spacing == BareTheme().spacing)
    #expect(DefaultTheme().shape == BareTheme().shape)
    #expect(DefaultTheme().animation == BareTheme().animation)
    #expect(DefaultTheme().colors == BareTheme().colors)
}
