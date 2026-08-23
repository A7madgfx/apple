//
//  TrackingDayTests.swift
//

import XCTest
@testable import GainTrack

final class TrackingDayTests: XCTestCase {
    func testBefore5AMBelongsToPreviousDay() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 10; comps.hour = 3; comps.minute = 30
        let date = Calendar.current.date(from: comps)!
        let start = TrackingDay.normalizedStart(for: date)
        let expected = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: -1, to: date)!)
        XCTAssertEqual(start, expected)
    }

    func testAfter5PMBelongsToSameDay() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 3; comps.day = 10; comps.hour = 18; comps.minute = 0
        let date = Calendar.current.date(from: comps)!
        let start = TrackingDay.normalizedStart(for: date)
        XCTAssertEqual(start, Calendar.current.startOfDay(for: date))
    }

    func testWorkoutSplitMapping() {
        XCTAssertEqual(WorkoutSplit.muscleGroup(for: .monday), "ظهر")
        XCTAssertEqual(WorkoutSplit.muscleGroup(for: .thursday), nil)
        XCTAssertEqual(WorkoutSplit.muscleGroup(for: .saturday), "أرجل")
    }
}
