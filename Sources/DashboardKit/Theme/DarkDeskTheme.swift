public struct DarkDeskTheme: Theme, Sendable {
    public let name: String
    public let defaultLayout: any Layout

    public init(
        name: String = "darkDesk",
        defaultLayout: any Layout = GridLayout()
    ) {
        self.name = name
        self.defaultLayout = defaultLayout
    }
}
