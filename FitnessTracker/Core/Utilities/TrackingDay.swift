//
//  TrackingDay.swift
//  Centralizes the 5:00 PM → 5:00 AM tracking-day logic used everywhere
//  (dashboard, notification scheduling, streaks).
//

import Foundation

enum TrackingDay {
    static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }()

    /// Given any timestamp, returns the normalized start date (midnight)
    /// of the tracking day it belongs to. A tracking day runs 17:00 → 05:00
    /// the next calendar day, so anything before 5:00 AM belongs to the
    /// *previous* calendar day's tracking day.
    static func normalizedStart(for date: Date) -> Date {
        let hour = calendar.component(.hour, from: date)
        let reference = hour < 5 ? calendar.date(byAdding: .day, value: -1, to: date)! : date
        return calendar.startOfDay(for: reference)
    }

    static func today() -> Date { normalizedStart(for: .now) }

    static func start(for trackingDayStart: Date) -> Date {
        calendar.date(bySettingHour: 17, minute: 0, second: 0, of: trackingDayStart)!
    }

    static func end(for trackingDayStart: Date) -> Date {
        let next = calendar.date(byAdding: .day, value: 1, to: trackingDayStart)!
        return calendar.date(bySettingHour: 5, minute: 0, second: 0, of: next)!
    }

    static func isCurrentlyActive(_ trackingDayStart: Date) -> Bool {
        let now = Date.now
        return now >= start(for: trackingDayStart) && now < end(for: trackingDayStart)
    }
}
