import Foundation

extension Date {
    /// e.g. "04:22 ص" using Arabic locale/numerals.
    func arabicClockString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }

    /// e.g. "الأربعاء، 12 أغسطس 2026"
    func arabicFullDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.setLocalizedDateFormatFromTemplate("EEEE d MMMM yyyy")
        return formatter.string(from: self)
    }

    func remainingTimeString(until date: Date) -> String {
        let interval = max(0, date.timeIntervalSince(self))
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
