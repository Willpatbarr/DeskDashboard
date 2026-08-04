public struct WidgetID: Hashable, Sendable {
    public var rawValue: String

    public init() {
        self.rawValue = UUIDFactory.makeID(prefix: "widget")
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
