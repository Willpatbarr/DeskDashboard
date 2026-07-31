/// The size of the surface the dashboard is drawn on, in points.
public struct Viewport: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(
        width: Double,
        height: Double
    ) {
        self.width = width
        self.height = height
    }

    /// The canvas theme size tokens are authored against: a 1280×800 desk
    /// display. A viewport this size resolves to scale `1`, i.e. the literal
    /// numbers written in `ThemeTypography` / `ThemeSpacing` / `ThemeShape`.
    public static let reference = Self(width: 1280, height: 800)
}

/// How a theme's *size* tokens adapt to the screen they land on.
///
/// The numbers in `ThemeTypography`, `ThemeSpacing` and `ThemeShape` are not
/// pixel values for one display — they're reference values authored at
/// `referenceViewport`. A renderer asks `scale(for:)` for the multiplier that
/// maps that reference canvas onto the real viewport and scales every size token
/// by it, so the same dashboard keeps its proportions on a 1024×600 Pi panel, a
/// 1280×800 window, or a 4K TV.
public struct ThemeMetrics: Equatable, Sendable {
    /// The viewport the theme's size tokens were authored at.
    public var referenceViewport: Viewport
    /// Floor on the derived scale, so a small window doesn't shrink text below
    /// legibility.
    public var minimumScale: Double
    /// Ceiling on the derived scale, so a very large screen doesn't blow the
    /// type up past what reads well from across the room.
    public var maximumScale: Double

    public init(
        referenceViewport: Viewport = .reference,
        minimumScale: Double = 0.55,
        maximumScale: Double = 3
    ) {
        self.referenceViewport = referenceViewport
        self.minimumScale = minimumScale
        self.maximumScale = maximumScale
    }

    public static let `default` = Self()

    /// Opts out of scaling: size tokens are used exactly as authored, whatever
    /// the screen. Useful for pinning a layout while designing it.
    public static let fixed = Self(minimumScale: 1, maximumScale: 1)

    /// The multiplier that maps `referenceViewport` onto `viewport`.
    ///
    /// Takes the *smaller* of the width and height ratios, so content scales
    /// uniformly (never stretched) and still fits at any aspect ratio, then
    /// clamps to `minimumScale...maximumScale`. Returns `1` for a degenerate
    /// (zero or negative) viewport, which is what a renderer sees before its
    /// first real layout pass.
    public func scale(
        for viewport: Viewport
    ) -> Double {
        guard referenceViewport.width > 0, referenceViewport.height > 0,
              viewport.width > 0, viewport.height > 0 else {
            return 1
        }

        let ratio = min(
            viewport.width / referenceViewport.width,
            viewport.height / referenceViewport.height
        )
        return min(max(ratio, minimumScale), maximumScale)
    }
}
