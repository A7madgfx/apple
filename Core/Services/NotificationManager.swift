import Foundation
import UserNotifications

/// Schedules local notifications for prayer awareness. Notifications are a scheduling/
/// awareness mechanism, NOT the mechanism used to play long-form Adhan audio — iOS local
/// notification sounds are capped to short system sound clips (a documented platform
/// limitation). The actual Adhan/custom playback is handled by `PrayerAudioManager` while
/// the app is foreground or alive-in-background under the Audio Background Mode.
final class NotificationManager {
    static let categoryIdentifier = "PRAYER_ALARM"
    static let stoodUpActionIdentifier = "STOOD_UP_FOR_PRAYER"

    func registerCategories() {
        let stoodUpAction = UNNotificationAction(
            identifier: Self.stoodUpActionIdentifier,
            title: "قمت للصلاة",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [stoodUpAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Clears any previously scheduled prayer notifications before scheduling a fresh batch —
    /// called whenever the schedule is recalculated (new day, location change, settings change).
    func clearAllScheduled() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func schedule(schedule: DailyPrayerSchedule, enabledPrayers: Set<Prayer>) {
        for entry in schedule.entries where enabledPrayers.contains(entry.prayer) {
            guard entry.alarmTime > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "حان وقت الصلاة"
            content.body = "صلاة \(entry.prayer.arabicName) — قمت للصلاة؟"
            content.categoryIdentifier = Self.categoryIdentifier
            content.sound = .default
            content.userInfo = ["prayer": entry.prayer.rawValue, "prayerTime": entry.time.timeIntervalSince1970]

            let interval = max(entry.alarmTime.timeIntervalSinceNow, 1)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: "prayer.\(entry.prayer.rawValue).\(Int(entry.alarmTime.timeIntervalSince1970))",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }
}
