import Foundation

public typealias DashboardClockHandler = (Date) -> Void

public protocol DashboardClock: AnyObject {
    var isRunning: Bool { get }

    func start(
        every refreshRate: RefreshRate,
        onTick: @escaping DashboardClockHandler
    )

    func stop()
}

public final class ManualDashboardClock: DashboardClock {
    private var onTick: DashboardClockHandler?
    public private(set) var isRunning: Bool = false
    public private(set) var refreshRate: RefreshRate?

    public init() {}

    public func start(
        every refreshRate: RefreshRate,
        onTick: @escaping DashboardClockHandler
    ) {
        self.refreshRate = refreshRate
        self.onTick = onTick
        self.isRunning = true
    }

    public func stop() {
        isRunning = false
        onTick = nil
    }

    public func advance(
        to date: Date
    ) {
        guard isRunning else {
            return
        }

        onTick?(date)
    }
}

public final class TimerDashboardClock: DashboardClock {
    private var timer: Timer?

    public var isRunning: Bool {
        timer != nil
    }

    public init() {}

    public func start(
        every refreshRate: RefreshRate,
        onTick: @escaping DashboardClockHandler
    ) {
        stop()

        let interval = max(refreshRate.seconds, 0.001)
        let handlerBox = DashboardClockHandlerBox(onTick)
        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { _ in
            handlerBox.onTick(Date())
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}

private final class DashboardClockHandlerBox: @unchecked Sendable {
    let onTick: DashboardClockHandler

    init(
        _ onTick: @escaping DashboardClockHandler
    ) {
        self.onTick = onTick
    }
}
