import DashboardKit
import Foundation

public struct ClockWidget: RenderableWidget {
    public var configuration: WidgetConfiguration
    private var displayOptions: ClockDisplayOptions
    private var model: ClockWidgetModel?

    public init(
        configuration: WidgetConfiguration = WidgetConfiguration(
            title: "Clock",
            size: .large,
            refreshRate: .seconds(1)
        ),
        displayOptions: ClockDisplayOptions = ClockDisplayOptions()
    ) {
        self.configuration = configuration
        self.displayOptions = displayOptions
    }

    var displayTime: String? {
        model?.displayTime
    }

    var displayDate: String? {
        model?.displayDate
    }

    public mutating func attach(environment: DashboardEnvironment) {
        let service = environment.service(for: ClockServiceKeys.clock)
            ?? SystemClockService()
        let model = ClockWidgetModel(
            service: service,
            displayOptions: displayOptions,
            timeZone: displayOptions.timeZone
        )

        model.activate()
        self.model = model
    }

    public mutating func update(environment: DashboardEnvironment) {
        model?.update(environment: environment)
    }

    public mutating func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {
        model?.tick(
            tick,
            environment: environment
        )
    }

    public mutating func detach() {
        model?.deactivate()
        model = nil
    }

    public func render(environment: DashboardEnvironment) -> WidgetContent {
        WidgetContent(
            title: configuration.title,
            primaryText: displayTime ?? "--:--",
            secondaryText: displayDate,
            metadata: [
                WidgetContentMetadata(
                    label: "Refresh",
                    value: "\(Int(environment.refreshRate.seconds))s"
                ),
                WidgetContentMetadata(
                    label: "Time Zone",
                    value: displayOptions.timeZone.identifier
                ),
            ]
        )
    }
}

public struct ClockDisplayOptions {
    public var showsSeconds: Bool
    public var showsDate: Bool
    public var timeZone: TimeZone

    public init(
        showsSeconds: Bool = false,
        showsDate: Bool = true,
        timeZone: TimeZone = .current
    ) {
        self.showsSeconds = showsSeconds
        self.showsDate = showsDate
        self.timeZone = timeZone
    }
}

extension ClockWidget {
    public func showSeconds(
        _ isShown: Bool = true
    ) -> Self {
        var copy = self
        copy.displayOptions.showsSeconds = isShown
        return copy
    }

    public func hideDate(
        _ isHidden: Bool = true
    ) -> Self {
        var copy = self
        copy.displayOptions.showsDate = !isHidden
        return copy
    }

    public func timeZone(
        _ timeZone: TimeZone
    ) -> Self {
        var copy = self
        copy.displayOptions.timeZone = timeZone
        return copy
    }

    public func timeZone(
        identifier: String
    ) -> Self {
        guard let timeZone = TimeZone(identifier: identifier) else {
            return self
        }

        return self.timeZone(timeZone)
    }
}
