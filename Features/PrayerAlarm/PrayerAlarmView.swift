import SwiftUI

/// Full-screen, non-dismissible-by-swipe prayer alarm screen. Deliberately has NO
/// "إيقاف" (stop) button — the only path forward is "قمت للصلاة" which opens the
/// camera verification flow.
struct PrayerAlarmView: View {
    let alarm: ActivePrayerAlarm
    @EnvironmentObject var appState: AppState
    @State private var showVerification = false

    var body: some View {
        ZStack {
            AppTheme.primaryBlack.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(AppTheme.primaryYellow)

                Text("حان وقت الصلاة")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)

                Text(alarm.prayer.arabicName)
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundStyle(AppTheme.primaryYellow)

                statusCard

                Text("قمت للصلاة؟")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.top, 12)

                Spacer()

                Button {
                    showVerification = true
                } label: {
                    Text("قمت للصلاة")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(AppTheme.primaryYellow, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)

                // Intentionally no stop/dismiss button here.
            }
        }
        .interactiveDismissDisabled(true)
        .fullScreenCover(isPresented: $showVerification) {
            PrayerMatCameraView(alarm: alarm, appState: appState)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var statusCard: some View {
        PrayerCard {
            VStack(alignment: .trailing, spacing: 8) {
                row("الصلاة", alarm.prayer.arabicName)
                row("وقت الصلاة", alarm.prayerTime.arabicClockString())
                row("وقت التنبيه", alarm.alarmStartTime.arabicClockString())
                row("مصدر الصوت", alarm.audioSourceDescription)
                row("الحالة", "نشط")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 28)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Spacer()
            Text(value).foregroundStyle(.white).font(.subheadline.bold())
            Text(label).foregroundStyle(AppTheme.secondaryText).font(.subheadline)
        }
    }
}
