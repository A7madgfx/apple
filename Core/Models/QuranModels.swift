import Foundation

/// Metadata for one of the 114 Surahs. Bundled locally (Resources/Quran/surah_index.json).
struct SurahInfo: Codable, Identifiable, Hashable {
    let number: Int
    let name: String
    let englishName: String
    let ayahCount: Int
    let revelation: String

    var id: Int { number }
}

/// A single ayah of Quran text, fetched from the configured source and cached locally.
struct Ayah: Codable, Identifiable, Hashable {
    let surahNumber: Int
    let ayahNumber: Int
    let text: String

    var id: String { "\(surahNumber):\(ayahNumber)" }
}

/// The Mushaf has 604 standard pages. We track reading position by page number.
struct QuranPage: Codable, Identifiable {
    let pageNumber: Int
    let ayahs: [Ayah]

    var id: Int { pageNumber }
}

/// Where the user is currently reading — persisted locally.
struct QuranReadingPosition: Codable {
    var pageNumber: Int
    var surahNumber: Int
    var updatedAt: Date
}
