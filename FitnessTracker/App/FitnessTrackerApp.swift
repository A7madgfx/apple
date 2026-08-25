//
//  FitnessTrackerApp.swift
//  GainTrack — ultra-personalized fitness & muscle-gaining habit tracker.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct FitnessTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var router = DeepLinkRouter()

    let modelContainer: ModelContainer = {
        let schema = Schema([DailyLog.self, TaskCompletion.self, ProgressPhoto.self, WaterIntakeLog.self, UserGoal.self])

        // Local-first, no special entitlements required. App Group (widget data
        // sharing) and CloudKit sync are opt-in upgrades for a properly provisioned
        // (paid Apple Developer account) build — see README for enabling them. A
        // sideloaded/ad-hoc build (AltStore, Sideloadly, personal-team signing) can't
        // get those entitlements approved, and requesting them anyway causes the OS
        // to kill the app at launch before any code runs — not a catchable Swift
        // error, hence keeping this plain by default.
        let plainConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [plainConfig]) {
            return container
        }
        // Last resort: in-memory store, so the app can still launch even if the
        // on-disk store is somehow unusable (e.g. corrupted after a schema change).
        let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: [memoryConfig])
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .appRootStyle()
                .environmentObject(router)
                .task {
                    NotificationManager.shared.registerCategories()
                    _ = await NotificationManager.shared.requestAuthorization()
                    let isWorkoutTomorrow = WorkoutSplit.isWorkoutDay(nextWeekday())
                    await NotificationManager.shared.rescheduleAll(isWorkoutDayTomorrowEvening: isWorkoutTomorrow)
                    ensureGoalExists()
                }
        }
        .modelContainer(modelContainer)
    }

    private func nextWeekday() -> Weekday {
        let today = Calendar.current.component(.weekday, from: .now)
        return Weekday(rawValue: today) ?? .sunday
    }

    private func ensureGoalExists() {
        let context = modelContainer.mainContext
        let existing = try? context.fetch(FetchDescriptor<UserGoal>())
        if existing?.isEmpty ?? true {
            context.insert(UserGoal())
            try? context.save()
        }
    }
}

/// Routes notification taps (e.g. the 5:00 AM "Quick Snap" prompt) to the
/// right in-app screen.
final class DeepLinkRouter: ObservableObject {
    enum Destination: Equatable { case none, morningCamera, waterLog }
    @Published var destination: Destination = .none
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let categoryID = response.notification.request.content.categoryIdentifier
        if categoryID == NotificationManager.categoryMorningReview {
            NotificationCenter.default.post(name: .openMorningCamera, object: nil)
        } else if response.actionIdentifier == "LOG_WATER" {
            NotificationCenter.default.post(name: .quickLogWater, object: nil)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

extension Notification.Name {
    static let openMorningCamera = Notification.Name("openMorningCamera")
    static let quickLogWater = Notification.Name("quickLogWater")
}
