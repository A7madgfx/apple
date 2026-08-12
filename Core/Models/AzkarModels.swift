import Foundation

enum AzkarCategory: String, Codable, CaseIterable, Identifiable {
    case morning, evening

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morning: return "أذكار الصباح"
        case .evening: return "أذكار المساء"
        }
    }

    var resourceFileName: String {
        switch self {
        case .morning: return "morning_azkar"
        case .evening: return "evening_azkar"
        }
    }
}

/// A single Dhikr item, bundled verbatim from the Islambook source. Text/counts are
/// never altered at runtime — only the user's live repetition progress is mutable state
/// held in the view model, not in this model.
struct Dhikr: Codable, Identifiable, Hashable {
    let id: Int
    let text: String
    let note: String?
    let repeatCount: Int
}
