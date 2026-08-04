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
