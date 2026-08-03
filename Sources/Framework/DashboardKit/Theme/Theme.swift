public protocol Theme: Sendable {
    var name: String { get }
    var colors: ThemeColors { get }
    var typography: ThemeTypography { get }
    var spacing: ThemeSpacing { get }
    var shape: ThemeShape { get }
    var animation: ThemeAnimation { get }
    /// How the theme's size tokens scale to the screen — see `ThemeMetrics`.
    var metrics: ThemeMetrics { get }
    var defaultLayout: any Layout { get }
}

public extension Theme {
    var colors: ThemeColors { .darkDesk }
    var typography: ThemeTypography { .default }
    var spacing: ThemeSpacing { .default }
    var shape: ThemeShape { .default }
    var animation: ThemeAnimation { .default }
    var metrics: ThemeMetrics { .default }
}

public extension Theme {
    /// The theme's size tokens resolved for a concrete viewport: typography,
    /// spacing and shape scaled by `metrics.scale(for:)`.
    ///
    /// This is the single place renderers go to turn reference sizes into real
    /// ones, so the native UI and the dev web page agree on what "a heading"
    /// means on a given screen.
    /// - Parameter multiplier: a manual nudge applied on top of the
    ///   viewport-derived scale, for tuning on a real display without changing
    ///   the theme. `1` leaves the computed scale alone.
    func sizes(
        for viewport: Viewport,
        multiplier: Double = 1
    ) -> ThemeSizes {
        let scale = metrics.scale(for: viewport) * (multiplier > 0 ? multiplier : 1)
        return ThemeSizes(
            scale: scale,
            typography: typography.scaled(by: scale),
            spacing: spacing.scaled(by: scale),
            shape: shape.scaled(by: scale)
        )
    }
}

/// A theme's size tokens after being scaled for one particular viewport.
public struct ThemeSizes: Equatable, Sendable {
    /// The multiplier already applied to everything below. Views with a one-off
    /// size of their own multiply by this to stay in proportion.
    public let scale: Double
    public let typography: ThemeTypography
    public let spacing: ThemeSpacing
    public let shape: ThemeShape
}

public struct ThemeColors: Equatable, Sendable {
    public var background: String
    public var surface: String
    public var primary: String
    public var secondary: String
    public var accent: String
    public var text: String
    public var mutedText: String
    /// Optional top-to-bottom background gradient stops (`#RRGGBB`). When empty,
    /// the flat `background` color is used instead.
    public var backgroundGradient: [String]

    public init(
        background: String,
        surface: String,
        primary: String,
        secondary: String,
        accent: String,
        text: String,
        mutedText: String,
        backgroundGradient: [String] = []
    ) {
        self.background = background
        self.surface = surface
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.text = text
        self.mutedText = mutedText
        self.backgroundGradient = backgroundGradient
    }

    public static let darkDesk = Self(
        background: "#090D14",
        surface: "#151B24",
        primary: "#E8EEF8",
        secondary: "#8D99AA",
        accent: "#36C2FF",
        text: "#F8FBFF",
        mutedText: "#A8B3C5"
    )

    /// Light palette: near-white background, dark text.
    public static let light = Self(
        background: "#EEF1F6",
        surface: "#FFFFFF",
        primary: "#0B1F3A",
        secondary: "#5B6B82",
        accent: "#0A84FF",
        text: "#1A2B45",
        mutedText: "#6B7A90"
    )

    /// High-contrast neon-on-black palette.
    public static let neon = Self(
        background: "#04050A",
        surface: "#0C0F1F",
        primary: "#F7F9FF",
        secondary: "#9A7BFF",
        accent: "#FF3DAE",
        text: "#EAF6FF",
        mutedText: "#7E8AB0"
    )

    /// Deep-green gradient with a mint accent and translucent panels — the
    /// "gradient clock" look (white numerals, green labels).
    public static let gradientClock = Self(
        background: "#0F2018",
        surface: "#05120B47",
        primary: "#FFFFFF",
        secondary: "#8FD79A",
        accent: "#8FD79A",
        text: "#FFFFFF",
        mutedText: "#6F9E78",
        backgroundGradient: ["#193326", "#0F2018", "#08110D"]
    )
}

/// Type tokens. The sizes are *reference* sizes, authored at
/// `ThemeMetrics.referenceViewport`, not fixed pixel values — renderers scale
/// them to the screen via `Theme.sizes(for:)`.
public struct ThemeTypography: Equatable, Sendable {
    public var fontFamily: String
    public var headingSize: Double
    public var bodySize: Double
    public var captionSize: Double
    public var headingWeight: Int
    public var bodyWeight: Int

    public init(
        fontFamily: String,
        headingSize: Double,
        bodySize: Double,
        captionSize: Double,
        headingWeight: Int,
        bodyWeight: Int
    ) {
        self.fontFamily = fontFamily
        self.headingSize = headingSize
        self.bodySize = bodySize
        self.captionSize = captionSize
        self.headingWeight = headingWeight
        self.bodyWeight = bodyWeight
    }

    public static let `default` = Self(
        fontFamily: "SF Pro",
        headingSize: 28,
        bodySize: 17,
        captionSize: 13,
        headingWeight: 700,
        bodyWeight: 500
    )

    /// Large, thin numerals with light labels — the gradient-clock aesthetic.
    public static let airy = Self(
        fontFamily: "SF Pro",
        headingSize: 44,
        bodySize: 18,
        captionSize: 14,
        headingWeight: 100,
        bodyWeight: 300
    )

    /// Like `airy`, but the supporting text (body/caption) is a notch larger for
    /// legibility on the curated board.
    public static let airyLegible = Self(
        fontFamily: "SF Pro",
        headingSize: 46,
        bodySize: 24,
        captionSize: 18,
        headingWeight: 100,
        bodyWeight: 300
    )

    /// Every size multiplied by `scale`. Weights and the font family are
    /// screen-independent, so they pass through untouched.
    public func scaled(
        by scale: Double
    ) -> Self {
        var copy = self
        copy.headingSize *= scale
        copy.bodySize *= scale
        copy.captionSize *= scale
        return copy
    }
}

public struct ThemeSpacing: Equatable, Sendable {
    public var widgetGap: Double
    public var tilePadding: Double
    public var sectionMargin: Double

    public init(
        widgetGap: Double,
        tilePadding: Double,
        sectionMargin: Double
    ) {
        self.widgetGap = widgetGap
        self.tilePadding = tilePadding
        self.sectionMargin = sectionMargin
    }

    public static let `default` = Self(
        widgetGap: 12,
        tilePadding: 16,
        sectionMargin: 20
    )

    /// Every gap multiplied by `scale`, so whitespace keeps its proportion to the
    /// type instead of crowding it on a big screen.
    public func scaled(
        by scale: Double
    ) -> Self {
        Self(
            widgetGap: widgetGap * scale,
            tilePadding: tilePadding * scale,
            sectionMargin: sectionMargin * scale
        )
    }
}

public struct ThemeShape: Equatable, Sendable {
    public var cornerRadius: Double
    public var borderWidth: Double
    public var elevation: Double

    public init(
        cornerRadius: Double,
        borderWidth: Double,
        elevation: Double
    ) {
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.elevation = elevation
    }

    public static let `default` = Self(
        cornerRadius: 8,
        borderWidth: 1,
        elevation: 2
    )

    /// Soft, pill-adjacent corners for the gradient-clock panels.
    public static let rounded = Self(
        cornerRadius: 28,
        borderWidth: 1,
        elevation: 2
    )

    /// Corner radius multiplied by `scale`. `borderWidth` and `elevation` stay
    /// put — a hairline border and a shadow depth read the same at any screen
    /// size, and scaling them just makes borders muddy.
    public func scaled(
        by scale: Double
    ) -> Self {
        Self(
            cornerRadius: cornerRadius * scale,
            borderWidth: borderWidth,
            elevation: elevation
        )
    }
}

public struct ThemeAnimation: Equatable, Sendable {
    public var transitionDuration: Double
    public var easing: String

    public init(
        transitionDuration: Double,
        easing: String
    ) {
        self.transitionDuration = transitionDuration
        self.easing = easing
    }

    public static let `default` = Self(
        transitionDuration: 0.18,
        easing: "easeInOut"
    )
}
