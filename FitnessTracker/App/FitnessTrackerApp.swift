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
        // CloudKit-backed configuration → automatic iCloud sync across the
        // user's devices, local-first (works fully offline, syncs opportunistically).
        // groupContainer shares the store with the Widget extension;
        // cloudKitDatabase adds automatic iCloud sync across devices.
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.com.gaintrack.app"),
            cloudKitDatabase: .private("iCloud.com.gaintrack.app")
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Fall back to a local-only (still shared with the widget) store
            // if CloudKit isn't available, e.g. no iCloud account signed in.
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false,
                                                  groupContainer: .identifier("group.com.gaintrack.app"))
            return try! ModelContainer(for: schema, configurations: [localConfig])
        }
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
