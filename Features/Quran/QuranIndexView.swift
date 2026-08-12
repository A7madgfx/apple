import SwiftUI

struct QuranIndexView: View {
    @EnvironmentObject var appState: AppState
    @State private var showPageIndex = false
    @State private var mode = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.primaryBlack.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("", selection: $mode) {
                        Text("فهرس السور").tag(0)
                        Text("فهرس الصفحات").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if mode == 0 {
                        surahList
                    } else {
                        QuranPageIndexView()
                    }
                }
            }
            .navigationTitle("القرآن الكريم")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var surahList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(appState.quranService.surahIndex) { surah in
                    NavigationLink(value: surah.number) {
                        surahRow(surah)
                    }
                }
            }
            .padding()
        }
        .navigationDestination(for: Int.self) { surahNumber in
            QuranReaderView(mode: .surah(surahNumber))
        }
    }

    private func surahRow(_ surah: SurahInfo) -> some View {
        PrayerCard {
            HStack {
                Text("\(surah.ayahCount) آية")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(surah.name).font(.headline).foregroundStyle(.white)
                    Text(surah.revelation).font(.caption2).foregroundStyle(AppTheme.secondaryText)
                }
                Text("\(surah.number)")
                    .font(.caption.bold())
                    .foregroundStyle(.black)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(AppTheme.primaryYellow))
            }
        }
    }
}
