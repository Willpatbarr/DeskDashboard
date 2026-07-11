public struct EnvironmentKey<Value>: Sendable {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}

public protocol DashboardService: AnyObject {}

public struct ServiceKey<Service: DashboardService>: Sendable {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}
