import SwiftUI

@main
struct PrayerCompanionApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .environment(\.layoutDirection, .rightToLeft)
                .preferredColorScheme(.dark)
                .environment(\.locale, Locale(identifier: "ar"))
        }
    }
}

/// Decides between Onboarding and the main tabbed app, and overlays the full-screen
/// prayer-alarm flow whenever an alarm is active — from anywhere in the app.
struct RootContainerView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        ZStack {
            if settings.hasCompletedOnboarding {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
        .fullScreenCover(item: $appState.activeAlarm) { alarm in
            PrayerAlarmView(alarm: alarm)
        }
    }
}
