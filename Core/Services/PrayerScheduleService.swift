import Foundation
import CoreLocation
import Combine

/// Owns the "today's schedule" state, recalculating it whenever the date, location, or
/// calculation settings change — never hard-coded, always derived.
@MainActor
final class PrayerScheduleService: ObservableObject {
    @Published private(set) var todaySchedule: DailyPrayerSchedule?
    @Published private(set) var lastError: String?

    private let locationService: LocationServicing
    private let settings: SettingsStore
    private let notificationManager: NotificationManager
    private var lastLocation: CLLocation?
    private var midnightTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(locationService: LocationServicing, settings: SettingsStore, notificationManager: NotificationManager) {
        self.locationService = locationService
        self.settings = settings
        self.notificationManager = notificationManager
        scheduleMidnightRefresh()

        // requestWhenInUseAuthorization() shows the system dialog asynchronously and
        // returns immediately, so a refresh() called right after it can easily race the
        // user's actual answer and fail. Retry automatically the moment the OS reports
        // the real (possibly newly-granted) status, instead of depending on timing.
        locationService.authorizationChanged
            .filter { $0 == .authorizedWhenInUse || $0 == .authorizedAlways }
            .sink { [weak self] _ in Task { await self?.refresh() } }
            .store(in: &cancellables)
    }

    /// Full refresh: get current location (or fall back to last-known), recompute, and
    /// reschedule notifications. Call on launch, on foreground, after settings changes,
    /// and once a day at midnight.
    func refresh() async {
        do {
            let location = try await resolveLocation()
            recompute(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            lastError = nil
        } catch {
            if let lat = settings.lastKnownLatitude, let lon = settings.lastKnownLongitude {
                recompute(latitude: lat, longitude: lon)
                lastError = nil
            } else {
                lastError = (error as? LocalizedError)?.errorDescription ?? "تعذر تحديد موقعك. يرجى تفعيل خدمات الموقع."
            }
        }
    }

    private func resolveLocation() async throws -> CLLocation {
        let location = try await locationService.currentLocation()
        if locationService.hasSignificantChange(from: lastLocation, to: location) || lastLocation == nil {
            lastLocation = location
            settings.lastKnownLatitude = location.coordinate.latitude
            settings.lastKnownLongitude = location.coordinate.longitude
        }
        return location
    }

    private func recompute(latitude: Double, longitude: Double) {
        let schedule = PrayerTimeCalculator.schedule(
            for: Date(),
            latitude: latitude,
            longitude: longitude,
            timeZone: .current,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod
        )
        todaySchedule = schedule
        notificationManager.clearAllScheduled()
        notificationManager.schedule(schedule: schedule, enabledPrayers: settings.enabledPrayers)
    }

    private func scheduleMidnightRefresh() {
        midnightTimer?.invalidate()
        let calendar = Calendar.current
        guard let tomorrowMidnight = calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0, second: 5), matchingPolicy: .nextTime) else { return }
        midnightTimer = Timer(fireAt: tomorrowMidnight, interval: 0, target: self, selector: #selector(midnightFired), userInfo: nil, repeats: false)
        if let midnightTimer { RunLoop.main.add(midnightTimer, forMode: .common) }
    }

    @objc private func midnightFired() {
        Task { await refresh() }
        scheduleMidnightRefresh()
    }
}
