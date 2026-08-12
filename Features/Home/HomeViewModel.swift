import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var now: Date = Date()
    private var timer: Timer?

    func startClock() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.now = Date() }
        }
    }

    deinit { timer?.invalidate() }
}
