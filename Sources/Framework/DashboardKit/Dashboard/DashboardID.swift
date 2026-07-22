public struct DashboardID: Hashable, Sendable {
    public var rawValue: String

    public init() {
        self.rawValue = UUIDFactory.makeID(prefix: "dashboard")
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
