public struct GridLayout: Layout, Sendable {
    public let name: String

    public init(name: String = "grid") {
        self.name = name
    }
}
