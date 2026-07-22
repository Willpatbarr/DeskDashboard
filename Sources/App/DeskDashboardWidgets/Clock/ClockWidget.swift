import DashboardKit
import Foundation

public struct ClockWidget: ServiceBackedWidget {
    public var configuration: WidgetConfiguration
    private var displayOptions: ClockDisplayOptions
    public var boundService: (any ClockService)?
    public var model: ClockWidgetModel?

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

    public var serviceKey: ServiceKey<any ClockService> { ClockServiceKeys.clock }

    public func makeModel(_ service: any ClockService) -> ClockWidgetModel {
        ClockWidgetModel(
            service: service,
            displayOptions: displayOptions,
            timeZone: displayOptions.timeZone
        )
    }

    public func makeFallbackService() -> any ClockService {
        SystemClockService()
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
