public struct RefreshRate: Equatable, Sendable {
    public var seconds: Double

    public init(seconds: Double) {
        self.seconds = seconds
    }

    public static func seconds(_ seconds: Double) -> Self {
        Self(seconds: seconds)
    }

    public static func minutes(_ minutes: Double) -> Self {
        Self(seconds: minutes * 60)
    }
}
