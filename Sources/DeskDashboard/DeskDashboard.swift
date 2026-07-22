import DashboardKit
import DeskDashboardDevTools
import DeskDashboardWidgets
import Foundation

@main
struct DeskDashboard {
    static func main() {
        let alarmStore = LocalAlarmStore()
        alarmStore.add(
            Alarm(
                id: "demo",
                label: "Demo alarm",
                date: Date().addingTimeInterval(120)
            )
        )

        // Push-backed indoor temperature: seeded so the tile isn't empty,
        // then overwritten by POSTs to /ingest/indoor-temperature.
        let indoorTemperature = PushIndoorTemperatureService(
            initialReading: TemperatureReading(
                celsius: 21.5,
                humidity: 44,
                timestamp: Date()
            )
        )

        let dashboard = Dashboard()
            .theme(DarkDeskTheme())
            .service(
                AnyAlarmService(alarmStore),
                for: AlarmServiceKeys.alarms
            )
            .service(
                AnyIndoorTemperatureService(indoorTemperature),
                for: IndoorTemperatureServiceKeys.indoorTemperature
            )
        let runner = DashboardRunner(dashboard: dashboard)

        runner.add(
            ClockWidget()
                .id("clock")
                .title("Clock")
                .size(.large)
                .showSeconds()
        )
        runner.add(
            AlarmWidget()
                .id("alarm")
                .title("Alarm")
        )
        runner.add(
            IndoorTemperatureWidget()
                .id("indoor")
                .title("Indoor")
        )

        // Both renderers are development tooling (DeskDashboardDevTools);
        // the real UI arrives with the SwiftOpenUI layer.
        if CommandLine.arguments.contains("--console") {
            let renderer = ConsoleRenderer()
            renderer.render(runner.attachedWidgetSnapshots)
            runner.start { _ in
                renderer.render(runner.attachedWidgetSnapshots)
            }
        } else {
            let renderer = DevWebRenderer(
                theme: runner.dashboard.configuration.theme,
                port: port(from: CommandLine.arguments)
            )
            registerIndoorTemperatureIngest(
                on: renderer,
                store: indoorTemperature
            )

            do {
                try renderer.start()
            } catch {
                print("Failed to start dev web renderer: \(error)")
                exit(1)
            }

            renderer.render(runner.attachedWidgetSnapshots)
            runner.start { _ in
                renderer.render(runner.attachedWidgetSnapshots)
            }
        }

        RunLoop.main.run()
    }

    private static func port(
        from arguments: [String]
    ) -> UInt16 {
        guard let index = arguments.firstIndex(of: "--port"),
              index + 1 < arguments.count,
              let value = UInt16(arguments[index + 1]) else {
            return 8642
        }

        return value
    }

    /// Accepts JSON `{ "value": <number>, "unit": "C"|"F", "humidity": <number> }`,
    /// normalizes to Celsius, stores it, logs the push, and echoes what it stored.
    private static func registerIndoorTemperatureIngest(
        on renderer: DevWebRenderer,
        store: PushIndoorTemperatureService
    ) {
        struct Payload: Decodable {
            var value: Double
            var unit: String?
            var humidity: Double?
        }

        renderer.registerPost(path: "/ingest/indoor-temperature") { body in
            guard let payload = try? JSONDecoder().decode(Payload.self, from: body) else {
                print("[ingest] indoor-temperature <- rejected (invalid JSON body)")
                return DevHTTPResponse(
                    contentType: "application/json",
                    body: Data(#"{"error":"expected JSON {value, unit?, humidity?}"}"#.utf8)
                )
            }

            let unit = (payload.unit ?? "C").uppercased()
            let celsius = unit == "F"
                ? (payload.value - 32) * 5 / 9
                : payload.value

            store.update(
                TemperatureReading(
                    celsius: celsius,
                    humidity: payload.humidity,
                    timestamp: Date()
                )
            )

            let stored = String(format: "%.1f", celsius)
            print("[ingest] indoor-temperature <- \(payload.value)°\(unit) => \(stored)°C")

            let humidityJSON = payload.humidity.map { String($0) } ?? "null"
            let echo = #"{"stored":"\#(stored)°C","humidity":\#(humidityJSON)}"#
            return DevHTTPResponse(
                contentType: "application/json",
                body: Data(echo.utf8)
            )
        }
    }
}
