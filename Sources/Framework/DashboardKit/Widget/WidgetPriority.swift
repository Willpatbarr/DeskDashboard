public struct WidgetPriority: Comparable, Sendable {
    public var rawValue: Int

    public init(_ rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let low = Self(250)
    public static let normal = Self(500)
    public static let high = Self(750)

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
