import DashboardKit

struct ClockWidget: RenderableWidget {
    var configuration: WidgetConfiguration
    private var model: ClockWidgetModel?

    init(
        configuration: WidgetConfiguration = WidgetConfiguration(
            title: "Clock",
            size: .large,
            refreshRate: .seconds(1)
        )
    ) {
        self.configuration = configuration
    }

    var displayTime: String? {
        model?.displayTime
    }

    var displayDate: String? {
        model?.displayDate
    }

    mutating func attach(environment: DashboardEnvironment) {
        let service = environment.service(for: ClockServiceKeys.clock)
            ?? AnyClockService(SystemClockService())
        let model = ClockWidgetModel(service: service)

        model.activate()
        self.model = model
    }

    mutating func update(environment: DashboardEnvironment) {
        model?.update(environment: environment)
    }

    mutating func detach() {
        model?.deactivate()
        model = nil
    }

    func render(environment: DashboardEnvironment) -> WidgetContent {
        WidgetContent(
            title: configuration.title,
            primaryText: displayTime ?? "--:--",
            secondaryText: displayDate,
            metadata: [
                WidgetContentMetadata(
                    label: "Refresh",
                    value: "\(Int(environment.refreshRate.seconds))s"
                ),
            ]
        )
    }
}
