public protocol Theme: Sendable {
    var name: String { get }
    var colors: ThemeColors { get }
    var typography: ThemeTypography { get }
    var spacing: ThemeSpacing { get }
    var shape: ThemeShape { get }
    var animation: ThemeAnimation { get }
    var defaultLayout: any Layout { get }
}

public extension Theme {
    var colors: ThemeColors { .darkDesk }
    var typography: ThemeTypography { .default }
    var spacing: ThemeSpacing { .default }
    var shape: ThemeShape { .default }
    var animation: ThemeAnimation { .default }
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
