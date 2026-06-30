public struct EnvironmentKey<Value>: Sendable {
    public let name: String

    public init(_ name: String) {
        self.name = name
    }
}
