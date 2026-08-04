public struct EnvironmentKey<Value>: Sendable {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}

/// A typed handle for a service registered on the dashboard. `Service` is the
/// service's own protocol (used as an existential), e.g.
/// `ServiceKey<any ClockService>("clock")` — no separate type-erasure box needed.
public struct ServiceKey<Service>: Sendable {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}
