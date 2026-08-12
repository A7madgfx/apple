import XCTest
@testable import PrayerCompanion

final class AzkarServiceTests: XCTestCase {
    func testMorningAzkarLoadsExpectedCountAndFirstItem() {
        let service = AzkarService()
        let items = service.load(.morning)
        XCTAssertEqual(items.count, 31)
        XCTAssertEqual(items.first?.repeatCount, 1)
        XCTAssertTrue(items.first?.text.contains("آية الكرسي") ?? false || items.first?.text.contains("الْحَيُّ الْقَيُّومُ") == true)
    }

    func testEveningAzkarLoadsExpectedCount() {
        let service = AzkarService()
        let items = service.load(.evening)
        XCTAssertEqual(items.count, 30)
    }

    func testRepeatCountsAreNeverZero() {
        let service = AzkarService()
        for item in service.load(.morning) + service.load(.evening) {
            XCTAssertGreaterThan(item.repeatCount, 0)
        }
    }
}
