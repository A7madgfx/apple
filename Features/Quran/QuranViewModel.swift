import Foundation

@MainActor
final class QuranViewModel: ObservableObject {
    @Published var ayahs: [Ayah] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let quranService: QuranService

    init(quranService: QuranService) {
        self.quranService = quranService
    }

    var surahIndex: [SurahInfo] { quranService.surahIndex }

    func loadSurah(_ number: Int) async {
        isLoading = true; errorMessage = nil
        do {
            ayahs = try await quranService.ayahs(forSurah: number)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "تعذر تحميل السورة."
        }
        isLoading = false
    }

    func loadPage(_ number: Int) async {
        isLoading = true; errorMessage = nil
        do {
            ayahs = try await quranService.ayahs(forPage: number)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "تعذر تحميل الصفحة."
        }
        isLoading = false
    }
}
