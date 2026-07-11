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

    public init(
        background: String,
        surface: String,
        primary: String,
        secondary: String,
        accent: String,
        text: String,
        mutedText: String
    ) {
        self.background = background
        self.surface = surface
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
        self.text = text
        self.mutedText = mutedText
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
