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
