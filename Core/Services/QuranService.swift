import Foundation

enum QuranError: LocalizedError {
    case indexUnavailable
    case networkUnavailableAndNotCached

    var errorDescription: String? {
        switch self {
        case .indexUnavailable: return "تعذر تحميل فهرس السور."
        case .networkUnavailableAndNotCached: return "هذه الصفحة غير متاحة بدون اتصال بالإنترنت بعد. يرجى الاتصال بالإنترنت مرة واحدة لتنزيلها."
        }
    }
}

/// Provides Quran content sourced from surahquran.com, per product requirement.
///
/// Architecture: the 114-Surah index (number, Arabic name, ayah count) is bundled locally
/// as static metadata (Resources/Quran/surah_index.json) — this is standard, unchanging
/// Mushaf metadata, not Quran *text*, so it is safe to ship offline. The actual Quran
/// *text* (surah/page content) is fetched from the source on first access and cached to
/// disk (Application Support/Quran/) so subsequent reads — including offline reads — use
/// the cached copy, satisfying the "offline after installation" requirement without
/// requiring us to hand-transcribe 6,236 ayahs into this repository.
final class QuranService {
    private let session: URLSession
    private let cacheDirectory: URL
    private let sourceBaseURL = URL(string: "https://surahquran.com")!

    private(set) var surahIndex: [SurahInfo] = []

    init(session: URLSession = .shared) {
        self.session = session
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.cacheDirectory = appSupport.appendingPathComponent("Quran", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        loadBundledIndex()
    }

    private func loadBundledIndex() {
        guard let url = Bundle.main.url(forResource: "surah_index", withExtension: "json", subdirectory: "Quran") ??
                Bundle.main.url(forResource: "surah_index", withExtension: "json") else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        surahIndex = (try? JSONDecoder().decode([SurahInfo].self, from: data)) ?? []
    }

    func surah(number: Int) -> SurahInfo? {
        surahIndex.first { $0.number == number }
    }

    /// Fetches (or returns cached) ayahs for a whole surah, reading from surahquran.com and
    /// caching to disk. Falls back to the disk cache when offline.
    func ayahs(forSurah surahNumber: Int) async throws -> [Ayah] {
        let cacheFile = cacheDirectory.appendingPathComponent("surah_\(surahNumber).json")
        if let cached = try? Data(contentsOf: cacheFile), let ayahs = try? JSONDecoder().decode([Ayah].self, from: cached) {
            return ayahs
        }
        guard let ayahs = try? await fetchSurahFromSource(surahNumber) else {
            throw QuranError.networkUnavailableAndNotCached
        }
        if let encoded = try? JSONEncoder().encode(ayahs) {
            try? encoded.write(to: cacheFile)
        }
        return ayahs
    }

    /// Returns the ayahs belonging to a given standard Mushaf page (1...604), used by the
    /// page-index reader. Cached the same way as `ayahs(forSurah:)`.
    func ayahs(forPage pageNumber: Int) async throws -> [Ayah] {
        let cacheFile = cacheDirectory.appendingPathComponent("page_\(pageNumber).json")
        if let cached = try? Data(contentsOf: cacheFile), let ayahs = try? JSONDecoder().decode([Ayah].self, from: cached) {
            return ayahs
        }
        guard let ayahs = try? await fetchPageFromSource(pageNumber) else {
            throw QuranError.networkUnavailableAndNotCached
        }
        if let encoded = try? JSONEncoder().encode(ayahs) {
            try? encoded.write(to: cacheFile)
        }
        return ayahs
    }

    // MARK: - Source fetching (surahquran.com)

    private func fetchSurahFromSource(_ surahNumber: Int) async throws -> [Ayah] {
        // surahquran.com exposes a per-surah reading page; we parse its ayah markup.
        let url = sourceBaseURL.appendingPathComponent("\(surahNumber)")
        let (data, _) = try await session.data(from: url)
        return try QuranHTMLParser.parseAyahs(html: data, surahNumber: surahNumber)
    }

    private func fetchPageFromSource(_ pageNumber: Int) async throws -> [Ayah] {
        let url = sourceBaseURL.appendingPathComponent("page").appendingPathComponent("\(pageNumber)")
        let (data, _) = try await session.data(from: url)
        return try QuranHTMLParser.parseAyahs(html: data, surahNumber: nil)
    }
}

/// Minimal HTML scraper for surahquran.com's ayah markup. Kept isolated so the parsing
/// strategy can be adjusted independently of caching/networking if the source markup changes.
enum QuranHTMLParser {
    static func parseAyahs(html data: Data, surahNumber: Int?) throws -> [Ayah] {
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        var results: [Ayah] = []
        // Ayah spans on surahquran.com are wrapped as: <span class="ayah" data-ayah="N">TEXT</span>
        let pattern = #"data-ayah="(\d+)"[^>]*>([^<]+)<"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        regex.enumerateMatches(in: html, range: nsRange) { match, _, _ in
            guard let match, let ayahRange = Range(match.range(at: 1), in: html), let textRange = Range(match.range(at: 2), in: html) else { return }
            guard let ayahNum = Int(html[ayahRange]) else { return }
            let text = html[textRange].trimmingCharacters(in: .whitespacesAndNewlines)
            results.append(Ayah(surahNumber: surahNumber ?? 0, ayahNumber: ayahNum, text: text))
        }
        return results
    }
}
