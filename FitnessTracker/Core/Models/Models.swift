//
//  Models.swift
//  FitnessTracker (GainTrack)
//
//  Core SwiftData models. All persisted locally and synced via CloudKit
//  when the user's iCloud account is available (see FitnessTrackerApp.swift).
//

import Foundation
import SwiftData

// MARK: - Task kinds tracked throughout the day

enum TaskKind: String, Codable, CaseIterable, Identifiable {
    case medication      // 5:00 PM
    case gymPrep         // 5:30 PM (workout days only)
    case supplement      // 10:00 PM (shake + creatine)
    case morningReview   // 5:00 AM photo + weight

    var id: String { rawValue }

    var titleAR: String {
        switch self {
        case .medication: return "الدواء"
        case .gymPrep: return "تجهيز الجيم"
        case .supplement: return "شيك + كرياتين"
        case .morningReview: return "مراجعة الصباح"
        }
    }

    /// Whether completing this task requires a photo attachment.
    var requiresPhoto: Bool {
        switch self {
        case .medication, .gymPrep, .supplement, .morningReview: return true
        }
    }

    var albumKey: String {
        switch self {
        case .medication: return "medication"
        case .gymPrep: return "gymPrep"
        case .supplement: return "supplements"
        case .morningReview: return "morning"
        }
    }
}

enum Weekday: Int, Codable, CaseIterable, Identifiable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
    var id: Int { rawValue }
}

/// The fixed weekly workout split. Not persisted — it's a static schedule,
/// but exposed as a lookup used by scheduling & UI.
enum WorkoutSplit {
    static func muscleGroup(for weekday: Weekday) -> String? {
        switch weekday {
        case .monday: return "ظهر"        // Back
        case .tuesday: return "زنود"       // Arms
        case .wednesday: return "صدر"      // Chest
        case .thursday: return nil         // Rest
        case .friday: return "أكتاف"       // Shoulders
        case .saturday: return "أرجل"      // Legs
        case .sunday: return nil           // Rest
        }
    }

    static var isWorkoutDay: (Weekday) -> Bool {
        { muscleGroup(for: $0) != nil }
    }
}

// MARK: - DailyLog

/// One "tracking day" — 5:00 PM through 5:00 AM the next calendar day.
/// `date` is the *start* date (the 5:00 PM day), which keeps the timeline
/// logic in `TrackingDay` consistent everywhere in the app.
@Model
final class DailyLog {
    @Attribute(.unique) var id: UUID
    var date: Date                       // normalized to the tracking day's start (midnight of the 5PM day)
    var isComplete: Bool
    var weightKg: Double?
    var reviewedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \TaskCompletion.dailyLog)
    var completions: [TaskCompletion] = []

    @Relationship(deleteRule: .cascade, inverse: \ProgressPhoto.dailyLog)
    var photos: [ProgressPhoto] = []

    init(date: Date) {
        self.id = UUID()
        self.date = date
        self.isComplete = false
        self.weightKg = nil
        self.reviewedAt = nil
    }

    var weekday: Weekday {
        Weekday(rawValue: Calendar.current.component(.weekday, from: date)) ?? .sunday
    }

    var muscleGroup: String? { WorkoutSplit.muscleGroup(for: weekday) }
    var isWorkoutDay: Bool { muscleGroup != nil }

    func completion(for kind: TaskKind) -> TaskCompletion? {
        completions.first { $0.kind == kind }
    }
}

// MARK: - TaskCompletion

@Model
final class TaskCompletion {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var completedAt: Date?
    var photoID: UUID?           // links to a ProgressPhoto if one was captured for this task

    var dailyLog: DailyLog?

    var kind: TaskKind {
        get { TaskKind(rawValue: kindRaw) ?? .medication }
        set { kindRaw = newValue.rawValue }
    }

    var isDone: Bool { completedAt != nil }

    init(kind: TaskKind) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.completedAt = nil
        self.photoID = nil
    }
}

// MARK: - ProgressPhoto

/// Metadata for a photo stored in the app's private document directory
/// (never in the system Photo Library unless the user explicitly exports it).
@Model
final class ProgressPhoto {
    @Attribute(.unique) var id: UUID
    var fileName: String          // relative path inside PhotoStorageService's root
    var albumKey: String          // "morning" | "medication" | "supplements" | "gymPrep"
    var takenAt: Date
    var weightKg: Double?         // only set for "morning" album photos

    var dailyLog: DailyLog?

    init(id: UUID = UUID(), fileName: String, albumKey: String, takenAt: Date, weightKg: Double? = nil) {
        self.id = id
        self.fileName = fileName
        self.albumKey = albumKey
        self.takenAt = takenAt
        self.weightKg = weightKg
    }
}

// MARK: - WaterIntakeLog

@Model
final class WaterIntakeLog {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var amountMl: Int

    init(timestamp: Date = .now, amountMl: Int = 250) {
        self.id = UUID()
        self.timestamp = timestamp
        self.amountMl = amountMl
    }
}

// MARK: - UserGoal (singleton-style settings row)

@Model
final class UserGoal {
    @Attribute(.unique) var id: UUID
    var startWeightKg: Double
    var targetWeightKg: Double
    var heightCm: Double
    var startDate: Date

    init(startWeightKg: Double = 57.0, targetWeightKg: Double = 75.0, heightCm: Double = 176.0, startDate: Date = .now) {
        self.id = UUID()
        self.startWeightKg = startWeightKg
        self.targetWeightKg = targetWeightKg
        self.heightCm = heightCm
        self.startDate = startDate
    }
}
