// GreenBoardTheme.swift — Theme: gradient palette, larger supporting text; the kiosk's own.

// The curated-board theme: the gradient-clock palette and shape, with larger
// supporting text. Reuses `ThemeColors.gradientClock` and `ThemeShape.rounded`
// from `GradientClockTheme.swift` rather than restating them — this is the
// cross-theme reuse the one-file-per-theme layout is meant to allow.

public extension ThemeTypography {
    /// Like `airy`, but body and caption are a notch larger, for legibility of
    /// the supporting lines on the curated board.
    static let airyLegible = Self(
        fontFamily: "system-ui",
        headingSize: 46,
        bodySize: 24,
        captionSize: 18,
        headingWeight: 100,
        bodyWeight: 300
    )
}

/// What the kiosk boots into: every curated board uses this.
public struct GreenBoardTheme: Theme, Sendable {
    public let name = "Green Board"
    public var colors: ThemeColors { .gradientClock }
    public var typography: ThemeTypography { .airyLegible }
    public var shape: ThemeShape { .rounded }

    public init() {}
}
