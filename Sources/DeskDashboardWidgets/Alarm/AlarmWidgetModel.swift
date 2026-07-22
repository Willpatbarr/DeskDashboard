import DashboardKit
import Foundation

// Alarm — the TRANSFORM layer. Each tick it decides which alarm matters now
// (soonest enabled, upcoming or currently firing) and formats it for display.
// This is the "clock provides rhythm, model provides judgement" rule (SDD §12).
final class AlarmWidgetModel: WidgetModel {
    /// How long an alarm counts as "firing" after its fire time.
    static let firingWindow: TimeInterval = 60

    private let service: any AlarmService
    private let displayOptions: AlarmDisplayOptions
    private let formatter: DateFormatter

    private(set) var displayNextAlarm: String?
    private(set) var displayCountdown: String?
    private(set) var nextAlarmLabel: String?
    private(set) var isFiring: Bool = false

    init(
        service: any AlarmService,
        displayOptions: AlarmDisplayOptions,
        locale: Locale = .current
    ) {
        self.service = service
        self.displayOptions = displayOptions
        self.formatter = DateFormatter()
        self.formatter.locale = locale
        self.formatter.timeZone = displayOptions.timeZone
    }

    // MARK: - WidgetModel lifecycle

    func activate() {
        refresh(at: Date())
    }

    func tick(
        _ tick: DashboardTick,
        environment: DashboardEnvironment
    ) {
        refresh(at: tick.date)
    }

    // MARK: - Choosing & formatting the active alarm

    func refresh(
        at date: Date
    ) {
        let enabledAlarms = service.alarms().filter(\.isEnabled)

        let firingAlarm = enabledAlarms
            .filter { $0.date <= date && date < $0.date + Self.firingWindow }
            .min { $0.date < $1.date }
        let upcomingAlarm = enabledAlarms
            .filter { $0.date >= date }
            .min { $0.date < $1.date }

        isFiring = firingAlarm != nil

        guard let alarm = firingAlarm ?? upcomingAlarm else {
            displayNextAlarm = nil
            displayCountdown = nil
            nextAlarmLabel = nil
            return
        }

        formatter.dateFormat = displayOptions.usesTwentyFourHour ? "H:mm" : "h:mm a"
        displayNextAlarm = formatter.string(from: alarm.date)
        nextAlarmLabel = alarm.label
        displayCountdown = isFiring
            ? nil
            : countdownText(until: alarm.date.timeIntervalSince(date))
    }

    // MARK: - Countdown helper

    private func countdownText(
        until interval: TimeInterval
    ) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))

        if totalSeconds >= 3600 {
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            return String(format: "in %dh %02dm", hours, minutes)
        }

        if totalSeconds >= 60 {
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return String(format: "in %dm %02ds", minutes, seconds)
        }

        return "in \(totalSeconds)s"
    }
}
