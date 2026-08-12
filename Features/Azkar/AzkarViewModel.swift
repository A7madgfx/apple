import Foundation

@MainActor
final class AzkarViewModel: ObservableObject {
    @Published var items: [Dhikr] = []
    @Published var progress: [Int: Int] = [:] // dhikr.id -> times said so far

    private let service: AzkarService
    let category: AzkarCategory

    init(category: AzkarCategory, service: AzkarService) {
        self.category = category
        self.service = service
        self.items = service.load(category)
    }

    func tap(_ dhikr: Dhikr) {
        let current = progress[dhikr.id] ?? 0
        guard current < dhikr.repeatCount else { return }
        progress[dhikr.id] = current + 1
    }

    func count(for dhikr: Dhikr) -> Int { progress[dhikr.id] ?? 0 }

    func resetAll() { progress = [:] }
}
