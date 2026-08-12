import XCTest
@testable import PrayerCompanion

final class SettingsStoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let suite = "test.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    func testPrayerTogglePersists() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.setPrayerEnabled(.fajr, enabled: false)
        XCTAssertFalse(store.isPrayerEnabled(.fajr))

        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertFalse(reloaded.isPrayerEnabled(.fajr))
    }

    func testCalculationMethodPersists() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.calculationMethod = .karachi
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.calculationMethod, .karachi)
    }

    func testDefaultsAreSaneOnFirstLaunch() {
        let store = SettingsStore(defaults: freshDefaults())
        XCTAssertEqual(store.enabledPrayers, Set(Prayer.allCases))
        XCTAssertEqual(store.audioSourceKind, .defaultAdhan)
        XCTAssertFalse(store.hasCompletedOnboarding)
    }
}
