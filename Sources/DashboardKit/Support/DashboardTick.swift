import Foundation

public struct DashboardTick: Equatable, Sendable {
    public var date: Date

    public init(date: Date = Date()) {
        self.date = date
    }
}
