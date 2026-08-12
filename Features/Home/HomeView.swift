import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBlack.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .trailing, spacing: 20) {
                        header
                        if let error = appState.scheduleService.lastError {
                            errorCard(error)
                        } else if let schedule = appState.scheduleService.todaySchedule {
                            nextPrayerCard(schedule)
                            prayerListCard(schedule)
                        } else {
                            ProgressView().tint(AppTheme.primaryYellow).padding(.top, 40)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear { viewModel.startClock() }
        .task { await appState.scheduleService.refresh() }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var header: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("السلام عليكم")
                .font(.title.bold())
                .foregroundStyle(.white)
            Text(viewModel.now.arabicFullDateString())
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func errorCard(_ message: String) -> some View {
        PrayerCard {
            VStack(alignment: .trailing, spacing: 12) {
                Text(message)
                    .foregroundStyle(AppTheme.error)
                    .multilineTextAlignment(.trailing)
                Button("فتح الإعدادات") { appState.permissionManager.openSystemSettings() }
                    .foregroundStyle(AppTheme.primaryYellow)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func nextPrayerCard(_ schedule: DailyPrayerSchedule) -> some View {
        let next = schedule.nextPrayer(after: viewModel.now)
        return PrayerCard(highlighted: true) {
            VStack(alignment: .trailing, spacing: 10) {
                Text("الصلاة القادمة")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                if let next {
                    Text(next.prayer.arabicName)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.primaryYellow)
                    Text(viewModel.now.remainingTimeString(until: next.time))
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                } else {
                    Text("انتهت صلوات اليوم")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func prayerListCard(_ schedule: DailyPrayerSchedule) -> some View {
        let next = schedule.nextPrayer(after: viewModel.now)
        return PrayerCard {
            VStack(spacing: 0) {
                ForEach(Array(schedule.entries.enumerated()), id: \.element.id) { index, entry in
                    prayerRow(entry, isNext: entry.prayer == next?.prayer)
                    if index < schedule.entries.count - 1 {
                        Divider().background(AppTheme.secondaryText.opacity(0.15))
                    }
                }
            }
        }
    }

    private func prayerRow(_ entry: PrayerTimeEntry, isNext: Bool) -> some View {
        HStack {
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(entry.prayer.arabicName)
                    .font(.headline)
                    .foregroundStyle(isNext ? AppTheme.primaryYellow : .white)
                Text("التنبيه \(entry.alarmTime.arabicClockString())")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Text(entry.time.arabicClockString())
                .font(.system(.title3, design: .rounded)).monospacedDigit()
                .foregroundStyle(isNext ? AppTheme.primaryYellow : AppTheme.secondaryText)
                .frame(width: 90, alignment: .leading)
        }
        .padding(.vertical, 10)
    }
}
