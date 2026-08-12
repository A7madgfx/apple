import SwiftUI

/// First-launch Arabic onboarding. Requests location + notifications permissions
/// separately and contextually, and clearly explains the background-audio behavior
/// (and its documented limitation) before the user reaches the home screen.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore
    @State private var page = 0

    private let pages: [(icon: String, title: String, body: String)] = [
        ("hand.raised.fill", "السلام عليكم", "رفيقك الشخصي لمواقيت الصلاة، القرآن الكريم، والأذكار — بتصميم بسيط ومباشر."),
        ("location.fill", "تحديد الموقع", "نحتاج إلى موقعك لحساب مواقيت الصلاة الخاصة بك بدقة. لن يُستخدم موقعك لأي غرض آخر."),
        ("bell.badge.fill", "تنبيهات الصلاة", "سنذكّرك بدخول وقت كل صلاة عبر إشعار محلي على جهازك."),
        ("speaker.wave.2.fill", "الأذان في الخلفية", "سيتم تشغيل الأذان أو النغمة التي تختارها بعد دخول الوقت بدقيقتين. قد يختلف استمرار التشغيل في الخلفية حسب قيود نظام iOS عند إغلاق التطبيق تمامًا."),
    ]

    var body: some View {
        ZStack {
            AppTheme.primaryBlack.ignoresSafeArea()
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: pages[page].icon)
                    .font(.system(size: 64))
                    .foregroundStyle(AppTheme.primaryYellow)
                Text(pages[page].title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text(pages[page].body)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 32)
                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { i in
                        Circle()
                            .fill(i == page ? AppTheme.primaryYellow : AppTheme.secondaryText.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                Button(action: advance) {
                    Text(page == pages.count - 1 ? "ابدأ" : "التالي")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primaryYellow, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }

    private func advance() {
        switch page {
        case 1: appState.permissionManager.requestLocation()
        case 2: Task { await appState.permissionManager.requestNotifications() }
        default: break
        }
        if page < pages.count - 1 {
            withAnimation { page += 1 }
        } else {
            settings.hasCompletedOnboarding = true
            Task { await appState.scheduleService.refresh() }
        }
    }
}
