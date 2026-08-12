import Foundation

/// The five daily prayers, in day order.
enum Prayer: String, CaseIterable, Codable, Identifiable {
    case fajr, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }
}

/// A calculated prayer time plus its mandatory +2 minute alarm offset.
struct PrayerTimeEntry: Identifiable, Codable {
    var id: String { prayer.rawValue }
    let prayer: Prayer
    let time: Date

    /// AlarmTime = CalculatedPrayerTime + 120 seconds. Applied independently per prayer.
    var alarmTime: Date { time.addingTimeInterval(120) }
}

/// A full day's schedule for a given location/date.
struct DailyPrayerSchedule: Codable {
    let date: Date
    let latitude: Double
    let longitude: Double
    let method: CalculationMethod
    let asrMethod: AsrJuristicMethod
    let entries: [PrayerTimeEntry]

    func entry(for prayer: Prayer) -> PrayerTimeEntry? {
        entries.first { $0.prayer == prayer }
    }

    /// The next upcoming prayer relative to `now`, wrapping to tomorrow's Fajr conceptually
    /// (caller handles day rollover by requesting tomorrow's schedule).
    func nextPrayer(after now: Date) -> PrayerTimeEntry? {
        entries.filter { $0.time > now }.min { $0.time < $1.time }
    }
}

/// Supported prayer-time calculation conventions (angles for Fajr/Isha in degrees).
enum CalculationMethod: String, CaseIterable, Codable, Identifiable {
    case muslimWorldLeague
    case egyptian
    case karachi
    case ummAlQura
    case dubai
    case moonsightingCommittee
    case northAmerica
    case kuwait
    case qatar
    case singapore

    var id: String { rawValue }

    var arabicName: String {
        switch self {
        case .muslimWorldLeague: return "رابطة العالم الإسلامي"
        case .egyptian: return "الهيئة المصرية العامة للمساحة"
        case .karachi: return "جامعة العلوم الإسلامية بكراتشي"
        case .ummAlQura: return "أم القرى (مكة المكرمة)"
        case .dubai: return "دبي"
        case .moonsightingCommittee: return "لجنة رؤية الهلال"
        case .northAmerica: return "الجمعية الإسلامية لأمريكا الشمالية (ISNA)"
        case .kuwait: return "الكويت"
        case .qatar: return "قطر"
        case .singapore: return "سنغافورة"
        }
    }

    /// (fajrAngle, ishaAngle or fixedIshaMinutes)
    var parameters: (fajrAngle: Double, ishaAngle: Double?, ishaMinutes: Double?) {
        switch self {
        case .muslimWorldLeague: return (18.0, 17.0, nil)
        case .egyptian: return (19.5, 17.5, nil)
        case .karachi: return (18.0, 18.0, nil)
        case .ummAlQura: return (18.5, nil, 90)
        case .dubai: return (18.2, 18.2, nil)
        case .moonsightingCommittee: return (18.0, 18.0, nil)
        case .northAmerica: return (15.0, 15.0, nil)
        case .kuwait: return (18.0, 17.5, nil)
        case .qatar: return (18.0, nil, 90)
        case .singapore: return (20.0, 18.0, nil)
        }
    }
}

enum AsrJuristicMethod: String, CaseIterable, Codable, Identifiable {
    case standard  // Shafi'i, Maliki, Hanbali — shadow factor 1
    case hanafi    // shadow factor 2

    var id: String { rawValue }

    var arabicName: String {
        switch self {
        case .standard: return "الجمهور (شافعي/مالكي/حنبلي)"
        case .hanafi: return "الحنفي"
        }
    }

    var shadowFactor: Double { self == .hanafi ? 2.0 : 1.0 }
}

enum PrayerAlarmStatus: String, Codable {
    case idle
    case active
    case verifying
    case completed
}

/// Represents the live state of a triggered prayer alarm.
struct ActivePrayerAlarm: Codable, Identifiable {
    var id: String { prayer.rawValue + String(prayerTime.timeIntervalSince1970) }
    let prayer: Prayer
    let prayerTime: Date
    let alarmStartTime: Date
    var audioSourceDescription: String
    var status: PrayerAlarmStatus
}
