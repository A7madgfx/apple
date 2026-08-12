import Foundation
import Combine
import UserNotifications

/// Composition root: builds and holds every service as a single source of truth,
/// injected into the SwiftUI environment from `PrayerCompanionApp`.
@MainActor
final class AppState: NSObject, ObservableObject {
    let settings: SettingsStore
    let locationService: LocationServicing
    let permissionManager: PermissionManager
    let scheduleService: PrayerScheduleService
    let audioManager: PrayerAudioManager
    let notificationManager: NotificationManager
    let cameraService: CameraService
    let recognitionService: PrayerMatRecognitionService
    let quranService: QuranService
    let azkarService: AzkarService

    @Published var activeAlarm: ActivePrayerAlarm?
    @Published var route: Route = .home

    enum Route: Hashable { case home, quran, azkar, settings }

    override init() {
        let settings = SettingsStore()
        let location = LocationService()
        self.settings = settings
        self.locationService = location
        self.permissionManager = PermissionManager(locationService: location)
        self.notificationManager = NotificationManager()
        self.scheduleService = PrayerScheduleService(locationService: location, settings: settings, notificationManager: notificationManager)
        self.audioManager = PrayerAudioManager(settings: settings)
        self.cameraService = CameraService()
        self.recognitionService = PrayerMatRecognitionService()
        self.quranService = QuranService()
        self.azkarService = AzkarService()
        super.init()

        AppServiceLocator.quranService = quranService
        AppServiceLocator.azkarService = azkarService
        notificationManager.registerCategories()
        UNUserNotificationCenter.current().delegate = self
        Task { await scheduleService.refresh() }
        scheduleAlarmWatcher()
    }

    /// Polls the current schedule once a second for prayers reaching their alarm time.
    /// (A lightweight in-app timer; system-level firing/awareness is additionally handled
    /// by NotificationManager's scheduled local notifications.)
    private var watcherTimer: Timer?
    private func scheduleAlarmWatcher() {
        watcherTimer?.invalidate()
        watcherTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkForDueAlarm() }
        }
    }

    private func checkForDueAlarm() {
        guard activeAlarm == nil, let schedule = scheduleService.todaySchedule else { return }
        let now = Date()
        for entry in schedule.entries where settings.isPrayerEnabled(entry.prayer) {
            if now >= entry.alarmTime && now < entry.alarmTime.addingTimeInterval(600) {
                trigger(entry: entry)
                break
            }
        }
    }

    private func trigger(entry: PrayerTimeEntry) {
        let sourceDescription = settings.audioSourceKind == .custom
            ? (settings.customAudioDisplayName ?? "نغمة مخصصة")
            : "الأذان الافتراضي"
        let alarm = ActivePrayerAlarm(prayer: entry.prayer, prayerTime: entry.time, alarmStartTime: Date(), audioSourceDescription: sourceDescription, status: .active)
        activeAlarm = alarm
        try? audioManager.start(for: alarm)
    }

    /// Called only after successful on-device prayer-mat verification.
    func markPrayerCompleted() {
        audioManager.stopAfterVerification()
        activeAlarm = nil
    }
}

extension AppState: @preconcurrency UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["prayer"] as? String, let prayer = Prayer(rawValue: raw) else { return }
        guard let schedule = scheduleService.todaySchedule, let entry = schedule.entry(for: prayer) else { return }
        if activeAlarm == nil {
            trigger(entry: entry)
        }
    }
}
