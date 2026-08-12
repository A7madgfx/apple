import Foundation

/// Loads Morning/Evening Azkar bundled verbatim from Resources/Azkar/*.json, transcribed
/// exactly (text + repetition counts) from the required Islambook source pages. Nothing is
/// added, removed, or reworded — this service only loads/decodes, it never generates text.
final class AzkarService {
    func load(_ category: AzkarCategory) -> [Dhikr] {
        guard let url = Bundle.main.url(forResource: category.resourceFileName, withExtension: "json", subdirectory: "Azkar") ??
                Bundle.main.url(forResource: category.resourceFileName, withExtension: "json") else {
            return []
        }
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Dhikr].self, from: data)) ?? []
    }
}
