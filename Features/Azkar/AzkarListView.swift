import SwiftUI

struct AzkarHomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBlack.ignoresSafeArea()
                VStack(spacing: 16) {
                    NavigationLink(value: AzkarCategory.morning) { categoryCard(.morning, icon: "sunrise.fill") }
                    NavigationLink(value: AzkarCategory.evening) { categoryCard(.evening, icon: "sunset.fill") }
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("الأذكار")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: AzkarCategory.self) { category in
                AzkarListView(category: category)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func categoryCard(_ category: AzkarCategory, icon: String) -> some View {
        PrayerCard {
            HStack {
                Image(systemName: "chevron.left").foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Text(category.title).font(.title3.bold()).foregroundStyle(.white)
                Image(systemName: icon).foregroundStyle(AppTheme.primaryYellow)
            }
        }
    }
}

struct AzkarListView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: AzkarViewModel

    init(category: AzkarCategory) {
        _viewModel = StateObject(wrappedValue: AzkarViewModel(category: category, service: AppServiceLocator.azkarService))
    }

    var body: some View {
        ZStack {
            AppTheme.primaryBlack.ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(viewModel.items) { dhikr in
                        dhikrCard(dhikr)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.category.title)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func dhikrCard(_ dhikr: Dhikr) -> some View {
        let done = viewModel.count(for: dhikr)
        let isComplete = done >= dhikr.repeatCount
        return PrayerCard {
            VStack(alignment: .trailing, spacing: 10) {
                Text(dhikr.text)
                    .font(.system(size: 19))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.white)
                if let note = dhikr.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Button {
                        viewModel.tap(dhikr)
                    } label: {
                        Text(isComplete ? "تم" : "[ \(done) / \(dhikr.repeatCount) ]")
                            .font(.headline)
                            .foregroundStyle(isComplete ? AppTheme.success : .black)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(isComplete ? AppTheme.success.opacity(0.15) : AppTheme.primaryYellow, in: Capsule())
                    }
                    .disabled(isComplete)
                    Spacer()
                    Text("عدد التكرار: \(dhikr.repeatCount)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
        }
    }
}
