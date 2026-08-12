import XCTest
@testable import PrayerCompanion

final class PrayerTimeCalculatorTests: XCTestCase {

    /// The mandatory +2 minute alarm offset must apply independently to every prayer.
    func testAlarmIsAlwaysPrayerTimePlusTwoMinutes() {
        let schedule = PrayerTimeCalculator.schedule(
            for: Date(),
            latitude: 21.3891, longitude: 39.8579, // Mecca
            timeZone: TimeZone(identifier: "Asia/Riyadh")!,
            method: .ummAlQura,
            asrMethod: .standard
        )
        for entry in schedule.entries {
            XCTAssertEqual(entry.alarmTime.timeIntervalSince(entry.time), 120, accuracy: 0.001, "\(entry.prayer.rawValue) alarm must be exactly +120s")
        }
    }

    func testAllFivePrayersArePresentAndOrdered() {
        let schedule = PrayerTimeCalculator.schedule(
            for: Date(),
            latitude: 24.7136, longitude: 46.6753, // Riyadh
            timeZone: TimeZone(identifier: "Asia/Riyadh")!,
            method: .ummAlQura,
            asrMethod: .standard
        )
        XCTAssertEqual(schedule.entries.map(\.prayer), [.fajr, .dhuhr, .asr, .maghrib, .isha])
        for i in 1..<schedule.entries.count {
            XCTAssertLessThan(schedule.entries[i - 1].time, schedule.entries[i].time)
        }
    }

    func testDifferentLocationsProduceDifferentTimes() {
        let riyadh = PrayerTimeCalculator.schedule(for: Date(), latitude: 24.7136, longitude: 46.6753, timeZone: TimeZone(identifier: "Asia/Riyadh")!, method: .ummAlQura, asrMethod: .standard)
        let london = PrayerTimeCalculator.schedule(for: Date(), latitude: 51.5072, longitude: -0.1276, timeZone: TimeZone(identifier: "Europe/London")!, method: .muslimWorldLeague, asrMethod: .standard)
        XCTAssertNotEqual(riyadh.entry(for: .fajr)?.time, london.entry(for: .fajr)?.time)
    }

    func testHanafiAsrIsLaterThanStandardAsr() {
        let standard = PrayerTimeCalculator.schedule(for: Date(), latitude: 41.0082, longitude: 28.9784, timeZone: TimeZone(identifier: "Europe/Istanbul")!, method: .muslimWorldLeague, asrMethod: .standard)
        let hanafi = PrayerTimeCalculator.schedule(for: Date(), latitude: 41.0082, longitude: 28.9784, timeZone: TimeZone(identifier: "Europe/Istanbul")!, method: .muslimWorldLeague, asrMethod: .hanafi)
        guard let s = standard.entry(for: .asr)?.time, let h = hanafi.entry(for: .asr)?.time else {
            return XCTFail("missing asr entry")
        }
        XCTAssertLessThan(s, h)
    }
}
