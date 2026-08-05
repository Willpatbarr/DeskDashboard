// This file is the theme SCAFFOLD, deliberately: the protocol, the token types,
// and the neutral `.default` each token falls back to. It holds no named
// palette, type scale or shape set of its own.
//
// Every concrete theme lives in one file under `Themes/`, and declares the named
// token values it introduces there — as extensions on these types, which Swift
// is happy to have in any file. So `ThemeColors.gradientClock` sits beside the
// theme that introduced it, and any *other* theme can still reuse it by name.
// Adding a theme should mean adding one file, not editing this one.

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

/// Defaults for every token, so a theme declares only what it actually changes
/// — a conformance can be as small as `struct T: Theme { let name = "T" }`.
///
/// `colors` falls back to `.darkDesk`, which is declared over in
/// `Themes/DarkDeskTheme.swift`: the framework's baseline theme owns the
/// baseline palette, rather than this file keeping a second copy of it.
public extension Theme {
    var colors: ThemeColors { .darkDesk }
    var typography: ThemeTypography { .default }
    var spacing: ThemeSpacing { .default }
    var shape: ThemeShape { .default }
    var animation: ThemeAnimation { .default }
    var metrics: ThemeMetrics { .default }
    var defaultLayout: any Layout { GridLayout() }
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

    // Named palettes live with the themes that introduce them, under `Themes/`.
}

/// Type tokens. The sizes are *reference* sizes, authored at
/// `ThemeMetrics.referenceViewport`, not fixed pixel values — renderers scale
/// them to the screen via `Theme.sizes(for:)`.
///
/// `fontFamily` reaches the **dev web renderer only**. SwiftCrossUI's `Font` has a
/// single identifier — `.system` — and no way to name a family, so the native UI
/// always draws in whatever the platform's UI font is. On the Pi that's chosen by
/// GTK (`~/.config/gtk-4.0/settings.ini`), not by this theme.
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

    // `.default` lives in `Themes/DefaultTheme.swift`; named type scales live with
    // the themes that introduce them, also under `Themes/`.

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

    // `.default` lives in `Themes/DefaultTheme.swift`.

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

    // `.default` lives in `Themes/DefaultTheme.swift`; named shape sets live with
    // the themes that introduce them, also under `Themes/`.

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

    // `.default` lives in `Themes/DefaultTheme.swift`.
}
