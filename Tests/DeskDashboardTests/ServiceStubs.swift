import DashboardKit
import DeskDashboardWidgets
import Foundation

// Closure-backed test doubles. These replace the old `Any*Service(closure:)`
// convenience inits that were deleted when services stopped needing per-widget
// type-erasure wrappers — services are now keyed on their protocol existential.

final class StubClockService: ClockService {
    private let provider: () -> Date
    init(currentDate: @escaping () -> Date) { provider = currentDate }
    func currentDate() -> Date { provider() }
}

final class StubMusicService: MusicService {
    private let provider: () -> NowPlaying?
    init(nowPlaying: @escaping () -> NowPlaying?) { provider = nowPlaying }
    func nowPlaying() -> NowPlaying? { provider() }
}

final class StubIndoorTemperatureService: IndoorTemperatureService {
    private let provider: () -> TemperatureReading?
    init(currentReading: @escaping () -> TemperatureReading?) { provider = currentReading }
    func currentReading() -> TemperatureReading? { provider() }
}

final class StubOutdoorTemperatureService: OutdoorTemperatureService {
    private let provider: () -> OutdoorConditions?
    init(currentConditions: @escaping () -> OutdoorConditions?) { provider = currentConditions }
    func currentConditions() -> OutdoorConditions? { provider() }
}
