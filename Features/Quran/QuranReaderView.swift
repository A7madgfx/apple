import SwiftUI

struct QuranReaderView: View {
    enum Mode: Hashable {
        case surah(Int)
        case page(Int)
    }

    let mode: Mode
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var viewModel: QuranViewModel
    @State private var currentIndex: Int

    init(mode: Mode) {
        self.mode = mode
        _viewModel = StateObject(wrappedValue: QuranViewModel(quranService: AppServiceLocator.quranService))
        switch mode {
        case .surah(let n): _currentIndex = State(initialValue: n)
        case .page(let n): _currentIndex = State(initialValue: n)
        }
    }

    var body: some View {
        ZStack {
            AppTheme.primaryBlack.ignoresSafeArea()
            if viewModel.isLoading {
                ProgressView().tint(AppTheme.primaryYellow)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(error).foregroundStyle(AppTheme.error).multilineTextAlignment(.center)
                    Button("إعادة المحاولة") { Task { await load() } }
                        .foregroundStyle(AppTheme.primaryYellow)
                }.padding()
            } else {
                ScrollView {
                    Text(readingText)
                        .font(.system(size: 24, weight: .regular))
                        .lineSpacing(14)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(24)
                }
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            if value.translation.width < -60 { goNext() }
                            else if value.translation.width > 60 { goPrevious() }
                        }
                )
            }
        }
        .navigationTitle(title)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task { await load() }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var readingText: String {
        viewModel.ayahs.map { "\($0.text) ﴿\($0.ayahNumber)﴾" }.joined(separator: " ")
    }

    private var title: String {
        switch mode {
        case .surah: return appState.quranService.surah(number: currentIndex)?.name ?? "سورة"
        case .page: return "صفحة \(currentIndex)"
        }
    }

    private func load() async {
        switch mode {
        case .surah:
            await viewModel.loadSurah(currentIndex)
            settings.lastQuranSurah = currentIndex
        case .page:
            await viewModel.loadPage(currentIndex)
            settings.lastQuranPage = currentIndex
        }
    }

    private func goNext() {
        switch mode {
        case .surah: currentIndex = min(114, currentIndex + 1)
        case .page: currentIndex = min(604, currentIndex + 1)
        }
        Task { await load() }
    }

    private func goPrevious() {
        switch mode {
        case .surah: currentIndex = max(1, currentIndex - 1)
        case .page: currentIndex = max(1, currentIndex - 1)
        }
        Task { await load() }
    }
}

/// Lightweight locator so screens instantiated by NavigationStack destinations (which
/// don't get initializer-injected services) can reach the shared QuranService.
/// Configured once from AppState at launch.
enum AppServiceLocator {
    static var quranService: QuranService!
}
