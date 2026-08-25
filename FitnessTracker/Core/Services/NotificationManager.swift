//
//  NotificationManager.swift
//  Schedules the fixed daily alert set described in the product spec.
//  Every notification fires once per day — no repeated nagging.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    // Notification category/action identifiers
    static let categoryMorningReview = "MORNING_REVIEW"
    static let categoryWaterReminder = "WATER_REMINDER"

    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Reschedules the entire fixed daily notification set. Call on launch,
    /// after settings changes, and right after midnight rollover.
    func rescheduleAll(isWorkoutDayTomorrowEvening: Bool) async {
        center.removeAllPendingNotificationRequests()

        // 5:00 PM — Daily medication alarm (tracking day start)
        await schedule(id: "medication", hour: 17, minute: 0,
                        title: "موعد الدواء 💊", body: "حان وقت جرعة اليوم")

        // 5:30 PM — Gym prep, workout days only
        if isWorkoutDayTomorrowEvening {
            await schedule(id: "gymPrep", hour: 17, minute: 30,
                            title: "جهّز شنطة الجيم 🏋️", body: "تمرين اليوم جاهز، يلا نتحرك")
        }

        // 10:00 PM — Shake & creatine
        await schedule(id: "supplement", hour: 22, minute: 0,
                        title: "شيك + كرياتين 🥤", body: "متنساش المكملات بتاعتك")

        // 5:00 AM — Morning review (photo + weight), tappable → camera
        await schedule(id: "morningReview", hour: 5, minute: 0,
                        title: "راجع يومك 📸⚖️", body: "صورة سريعة + سجل وزنك النهاردة",
                        categoryID: Self.categoryMorningReview)

        // Water reminders every 2 hours, 2:00 PM → 6:00 AM quiet-period boundary.
        // Fires at 14:00, 16:00, ... 04:00, then frozen 06:00–14:00.
        var hour = 14
        while true {
            await schedule(id: "water_\(hour)", hour: hour % 24, minute: 0,
                            title: "اشرب مية 💧", body: "خد شوية مية دلوقتي",
                            categoryID: Self.categoryWaterReminder)
            if hour % 24 == 4 { break }
            hour += 2
        }
    }

    private func schedule(id: String, hour: Int, minute: Int, title: String, body: String, categoryID: String? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let categoryID { content.categoryIdentifier = categoryID }

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    /// Registers notification actions/categories at launch.
    func registerCategories() {
        let openCamera = UNNotificationAction(identifier: "OPEN_CAMERA", title: "افتح الكاميرا", options: [.foreground])
        let reviewCategory = UNNotificationCategory(
            identifier: Self.categoryMorningReview,
            actions: [openCamera],
            intentIdentifiers: [],
            options: []
        )

        let logWater = UNNotificationAction(identifier: "LOG_WATER", title: "سجّل كوب مية", options: [])
        let waterCategory = UNNotificationCategory(
            identifier: Self.categoryWaterReminder,
            actions: [logWater],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([reviewCategory, waterCategory])
    }

    /// The 6:00 AM – 2:00 PM quiet period: water notifications are frozen entirely.
    static func isWithinWaterQuietPeriod(_ date: Date = .now) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        return hour >= 6 && hour < 14
    }
}
