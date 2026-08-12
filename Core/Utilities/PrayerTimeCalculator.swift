import Foundation

/// Computes the five daily prayer times from first principles (solar position astronomy),
/// following the well-known public-domain PrayTimes.org method. No network dependency,
/// no hard-coded times — every result is derived from date + coordinates + calculation method.
enum PrayerTimeCalculator {

    /// Computes today's schedule for the given date/location/method. `date` should fall on
    /// the local calendar day to compute; the algorithm derives everything from that day's
    /// Julian date plus the location's latitude/longitude and the timezone's UTC offset.
    static func schedule(
        for date: Date,
        latitude: Double,
        longitude: Double,
        timeZone: TimeZone,
        method: CalculationMethod,
        asrMethod: AsrJuristicMethod
    ) -> DailyPrayerSchedule {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              let dayStart = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 0, minute: 0, second: 0, timeZone: timeZone))
        else {
            return DailyPrayerSchedule(date: date, latitude: latitude, longitude: longitude, method: method, asrMethod: asrMethod, entries: [])
        }

        let jd = julianDate(year: year, month: month, day: day) - longitude / (15.0 * 24.0)
        let tzOffset = Double(timeZone.secondsFromGMT(for: dayStart)) / 3600.0
        let sun = Sun(julianDate: jd, latitude: latitude, longitude: longitude)
        let params = method.parameters

        let noon = sun.midDay(dayFraction: 12.0 / 24.0)
        let fajr = sun.angleTime(angle: params.fajrAngle, dayFraction: 5.0 / 24.0, direction: .before)
        let asr = sun.asrTime(shadowFactor: asrMethod.shadowFactor, dayFraction: 13.0 / 24.0)
        let sunset = sun.angleTime(angle: 0.833, dayFraction: 18.0 / 24.0, direction: .after)
        let maghrib = sunset
        let isha: Double
        if let ishaMinutes = params.ishaMinutes {
            isha = maghrib + ishaMinutes / 60.0
        } else {
            isha = sun.angleTime(angle: params.ishaAngle ?? 18.0, dayFraction: 18.0 / 24.0, direction: .after)
        }

        // Adjust every raw hour value (still in "local solar" terms) into local clock time.
        func toLocalHour(_ raw: Double) -> Double {
            fixHour(raw + tzOffset - longitude / 15.0)
        }

        func makeDate(_ localHour: Double) -> Date {
            dayStart.addingTimeInterval(localHour * 3600.0)
        }

        let entries: [PrayerTimeEntry] = [
            PrayerTimeEntry(prayer: .fajr, time: makeDate(toLocalHour(fajr))),
            PrayerTimeEntry(prayer: .dhuhr, time: makeDate(toLocalHour(noon))),
            PrayerTimeEntry(prayer: .asr, time: makeDate(toLocalHour(asr))),
            PrayerTimeEntry(prayer: .maghrib, time: makeDate(toLocalHour(maghrib))),
            PrayerTimeEntry(prayer: .isha, time: makeDate(toLocalHour(isha))),
        ]

        return DailyPrayerSchedule(date: date, latitude: latitude, longitude: longitude, method: method, asrMethod: asrMethod, entries: entries)
    }

    private static func julianDate(year: Int, month: Int, day: Int) -> Double {
        var y = year
        var m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(Double(y) / 100.0)
        let b = 2 - a + floor(a / 4.0)
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + b - 1524.5
    }
}

private func fixHour(_ h: Double) -> Double {
    var h = h.truncatingRemainder(dividingBy: 24)
    if h < 0 { h += 24 }
    return h
}

private enum SunDirection { case before, after }

/// Solar-position helper. Formulas follow the NOAA-derived approximations used by
/// PrayTimes.org (public domain), reproduced here to avoid any network dependency.
private struct Sun {
    let julianDate: Double
    let latitude: Double
    let longitude: Double

    private func degToRad(_ d: Double) -> Double { d * .pi / 180 }
    private func radToDeg(_ r: Double) -> Double { r * 180 / .pi }
    private func sinDeg(_ d: Double) -> Double { sin(degToRad(d)) }
    private func cosDeg(_ d: Double) -> Double { cos(degToRad(d)) }
    private func tanDeg(_ d: Double) -> Double { tan(degToRad(d)) }
    private func arccosDeg(_ x: Double) -> Double { radToDeg(acos(max(-1, min(1, x)))) }
    private func arccotDeg(_ x: Double) -> Double { radToDeg(atan(1.0 / x)) }
    private func fixAngle(_ a: Double) -> Double {
        var a = a.truncatingRemainder(dividingBy: 360)
        if a < 0 { a += 360 }
        return a
    }

    /// Sun declination & equation-of-time (hours) at julianDate + dayFraction.
    private func position(dayFraction: Double) -> (declination: Double, equationOfTime: Double) {
        let d = (julianDate + dayFraction) - 2451545.0
        let g = fixAngle(357.529 + 0.98560028 * d)
        let q = fixAngle(280.459 + 0.98564736 * d)
        let l = fixAngle(q + 1.915 * sinDeg(g) + 0.020 * sinDeg(2 * g))
        let e = 23.439 - 0.00000036 * d
        let ra = fixHour(radToDeg(atan2(cosDeg(e) * sinDeg(l), cosDeg(l))) / 15.0)
        let eqt = q / 15.0 - ra
        let decl = radToDeg(asin(sinDeg(e) * sinDeg(l)))
        return (decl, eqt)
    }

    /// Local solar noon (hours, "solar" frame — caller applies timezone/longitude offset).
    func midDay(dayFraction: Double) -> Double {
        let eqt = position(dayFraction: dayFraction).equationOfTime
        return fixHour(12.0 - eqt)
    }

    /// Time (solar-frame hours) at which the sun is `angle` degrees below the horizon,
    /// before or after solar noon. One Newton-style refinement pass for accuracy.
    func angleTime(angle: Double, dayFraction: Double, direction: SunDirection) -> Double {
        var t = dayFraction
        var result = midDay(dayFraction: t)
        for _ in 0..<2 {
            let (decl, _) = position(dayFraction: t)
            let noon = midDay(dayFraction: t)
            let numerator = -sinDeg(angle) - sinDeg(decl) * sinDeg(latitude)
            let denominator = cosDeg(decl) * cosDeg(latitude)
            guard denominator != 0 else { break }
            let hourAngle = arccosDeg(numerator / denominator) / 15.0
            result = direction == .before ? noon - hourAngle : noon + hourAngle
            t = fixHour(result) / 24.0
        }
        return result
    }

    /// Asr time via the shadow-length method: shadow = factor + tan(|lat - decl|).
    func asrTime(shadowFactor: Double, dayFraction: Double) -> Double {
        var t = dayFraction
        var result = midDay(dayFraction: t)
        for _ in 0..<2 {
            let (decl, _) = position(dayFraction: t)
            let noon = midDay(dayFraction: t)
            let angle = -arccotDeg(shadowFactor + tanDeg(abs(latitude - decl)))
            let numerator = sinDeg(angle) - sinDeg(decl) * sinDeg(latitude)
            let denominator = cosDeg(decl) * cosDeg(latitude)
            guard denominator != 0 else { break }
            let hourAngle = arccosDeg(numerator / denominator) / 15.0
            result = noon + hourAngle
            t = fixHour(result) / 24.0
        }
        return result
    }
}
