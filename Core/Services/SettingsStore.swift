import Foundation
import Combine

/// Which audio the app plays when a prayer alarm fires.
enum AudioSourceKind: String, Codable {
    case defaultAdhan
    case custom
}

/// All user-configurable settings, persisted locally via UserDefaults (no account, no cloud).
/// Exposed as an ObservableObject so SwiftUI views react to changes immediately.
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private enum Keys {
        static let enabledPrayers = "settings.enabledPrayers"
        static let audioSourceKind = "settings.audioSourceKind"
        static let customAudioBookmark = "settings.customAudioBookmark"
        static let customAudioDisplayName = "settings.customAudioDisplayName"
        static let volume = "settings.volume"
        static let calculationMethod = "settings.calculationMethod"
        static let asrMethod = "settings.asrMethod"
        static let latitude = "settings.latitude"
        static let longitude = "settings.longitude"
        static let placemarkName = "settings.placemarkName"
        static let hasCompletedOnboarding = "settings.hasCompletedOnboarding"
        static let lastQuranPage = "settings.lastQuranPage"
        static let lastQuranSurah = "settings.lastQuranSurah"
    }

    @Published var enabledPrayers: Set<Prayer> {
        didSet { defaults.set(enabledPrayers.map(\.rawValue), forKey: Keys.enabledPrayers) }
    }
    @Published var audioSourceKind: AudioSourceKind {
        didSet { defaults.set(audioSourceKind.rawValue, forKey: Keys.audioSourceKind) }
    }
    @Published var customAudioDisplayName: String? {
        didSet { defaults.set(customAudioDisplayName, forKey: Keys.customAudioDisplayName) }
    }
    @Published var volume: Float {
        didSet { defaults.set(volume, forKey: Keys.volume) }
    }
    @Published var calculationMethod: CalculationMethod {
        didSet { defaults.set(calculationMethod.rawValue, forKey: Keys.calculationMethod) }
    }
    @Published var asrMethod: AsrJuristicMethod {
        didSet { defaults.set(asrMethod.rawValue, forKey: Keys.asrMethod) }
    }
    @Published var lastKnownLatitude: Double? {
        didSet { defaults.set(lastKnownLatitude, forKey: Keys.latitude) }
    }
    @Published var lastKnownLongitude: Double? {
        didSet { defaults.set(lastKnownLongitude, forKey: Keys.longitude) }
    }
    @Published var placemarkName: String? {
        didSet { defaults.set(placemarkName, forKey: Keys.placemarkName) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }
    @Published var lastQuranPage: Int {
        didSet { defaults.set(lastQuranPage, forKey: Keys.lastQuranPage) }
    }
    @Published var lastQuranSurah: Int {
        didSet { defaults.set(lastQuranSurah, forKey: Keys.lastQuranSurah) }
    }

    /// Security-scoped bookmark for the user-picked custom audio file (Files/Documents picker).
    var customAudioBookmark: Data? {
        get { defaults.data(forKey: Keys.customAudioBookmark) }
        set { defaults.set(newValue, forKey: Keys.customAudioBookmark) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedPrayers = defaults.array(forKey: Keys.enabledPrayers) as? [String]
        self.enabledPrayers = storedPrayers.map { Set($0.compactMap(Prayer.init(rawValue:))) } ?? Set(Prayer.allCases)

        self.audioSourceKind = AudioSourceKind(rawValue: defaults.string(forKey: Keys.audioSourceKind) ?? "") ?? .defaultAdhan
        self.customAudioDisplayName = defaults.string(forKey: Keys.customAudioDisplayName)
        self.volume = defaults.object(forKey: Keys.volume) != nil ? defaults.float(forKey: Keys.volume) : 1.0
        self.calculationMethod = CalculationMethod(rawValue: defaults.string(forKey: Keys.calculationMethod) ?? "") ?? .ummAlQura
        self.asrMethod = AsrJuristicMethod(rawValue: defaults.string(forKey: Keys.asrMethod) ?? "") ?? .standard
        self.lastKnownLatitude = defaults.object(forKey: Keys.latitude) as? Double
        self.lastKnownLongitude = defaults.object(forKey: Keys.longitude) as? Double
        self.placemarkName = defaults.string(forKey: Keys.placemarkName)
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.lastQuranPage = defaults.object(forKey: Keys.lastQuranPage) as? Int ?? 1
        self.lastQuranSurah = defaults.object(forKey: Keys.lastQuranSurah) as? Int ?? 1
    }

    func isPrayerEnabled(_ prayer: Prayer) -> Bool { enabledPrayers.contains(prayer) }

    func setPrayerEnabled(_ prayer: Prayer, enabled: Bool) {
        if enabled { enabledPrayers.insert(prayer) } else { enabledPrayers.remove(prayer) }
    }
}
