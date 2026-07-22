import DashboardKit
import Foundation

// Alarm — the DISPLAY layer. Inert until attached; renders the model's chosen
// alarm as next-time / countdown, or a "Ringing!" state (which is the first
// real use of WidgetContent.accessoryText, carrying the "RINGING" badge).

// MARK: - Widget

public struct AlarmWidget: ServiceBackedWidget {
    public var configuration: WidgetConfiguration
    private var displayOptions: AlarmDisplayOptions
    public var boundService: (any AlarmService)?
    public var model: AlarmWidgetModel?

    public init(
        configuration: WidgetConfiguration = WidgetConfiguration(
            title: "Alarm",
            size: .medium,
            refreshRate: .seconds(1)
        ),
        displayOptions: AlarmDisplayOptions = AlarmDisplayOptions()
    ) {
        self.configuration = configuration
        self.displayOptions = displayOptions
    }

    var displayNextAlarm: String? {
        model?.displayNextAlarm
    }

    var displayCountdown: String? {
        model?.displayCountdown
    }

    var isFiring: Bool {
        model?.isFiring ?? false
    }

    // MARK: - Service-backed lifecycle

    public var serviceKey: ServiceKey<any AlarmService> { AlarmServiceKeys.alarms }

    public func makeModel(_ service: any AlarmService) -> AlarmWidgetModel {
        AlarmWidgetModel(service: service, displayOptions: displayOptions)
    }

    public func makeFallbackService() -> any AlarmService {
        LocalAlarmStore()
    }

    // MARK: - Rendering

    public func render(environment: DashboardEnvironment) -> WidgetContent {
        var metadata: [WidgetContentMetadata] = []

        if let label = model?.nextAlarmLabel {
            metadata.append(
                WidgetContentMetadata(
                    label: "Alarm",
                    value: label
                )
            )
        }

        metadata.append(
            WidgetContentMetadata(
                label: "Time Zone",
                value: displayOptions.timeZone.identifier
            )
        )

        return WidgetContent(
            title: configuration.title,
            primaryText: displayNextAlarm ?? "No alarms",
            secondaryText: isFiring ? "Ringing!" : displayCountdown,
            accessoryText: isFiring ? "RINGING" : nil,
            metadata: metadata
        )
    }
}

// MARK: - Display options

public struct AlarmDisplayOptions {
    public var usesTwentyFourHour: Bool
    public var timeZone: TimeZone

    public init(
        usesTwentyFourHour: Bool = false,
        timeZone: TimeZone = .current
    ) {
        self.usesTwentyFourHour = usesTwentyFourHour
        self.timeZone = timeZone
    }
}

// MARK: - Modifiers (composition over configuration)

extension AlarmWidget {
    public func twentyFourHour(
        _ isOn: Bool = true
    ) -> Self {
        var copy = self
        copy.displayOptions.usesTwentyFourHour = isOn
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
