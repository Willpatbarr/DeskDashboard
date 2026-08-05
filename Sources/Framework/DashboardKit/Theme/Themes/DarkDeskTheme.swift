// The framework's baseline theme, and the palette it introduces.
//
// Pattern for every theme file (see `Theme.swift` for the scaffold): declare the
// named token values this theme introduces as extensions on the token types,
// then the theme itself. Values declared here are reusable by name from any
// other theme — `.darkDesk` is a module-wide name, not a private detail.

public extension ThemeColors {
    /// Near-black blues with a bright cyan accent. Also the palette the `Theme`
    /// protocol falls back to when a theme doesn't name one, so this is the one
    /// palette the scaffold refers to by name.
    static let darkDesk = Self(
        background: "#090D14",
        surface: "#151B24",
        primary: "#E8EEF8",
        secondary: "#8D99AA",
        accent: "#36C2FF",
        text: "#F8FBFF",
        mutedText: "#A8B3C5"
    )
}

/// Takes every scaffold default. It also doubles as the generic "composed theme"
/// box — its init accepts any combination of tokens, which is how a one-off
/// variation can be built without declaring a new type.
public struct DarkDeskTheme: Theme, Sendable {
    public let name: String
    public let colors: ThemeColors
    public let typography: ThemeTypography
    public let spacing: ThemeSpacing
    public let shape: ThemeShape
    public let animation: ThemeAnimation
    public let metrics: ThemeMetrics
    public let defaultLayout: any Layout

    public init(
        name: String = "darkDesk",
        colors: ThemeColors = .darkDesk,
        typography: ThemeTypography = .default,
        spacing: ThemeSpacing = .default,
        shape: ThemeShape = .default,
        animation: ThemeAnimation = .default,
        metrics: ThemeMetrics = .default,
        defaultLayout: any Layout = GridLayout()
    ) {
        self.name = name
        self.colors = colors
        self.typography = typography
        self.spacing = spacing
        self.shape = shape
        self.animation = animation
        self.metrics = metrics
        self.defaultLayout = defaultLayout
    }
}
