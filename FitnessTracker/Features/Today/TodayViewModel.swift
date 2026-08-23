//
//  TodayViewModel.swift
//

import SwiftUI
import SwiftData

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var streak: Int = 0

    /// Fetches (or lazily creates) today's DailyLog and ensures its
    /// TaskCompletion rows exist for the applicable task kinds.
    func ensureTodayLog(context: ModelContext) -> DailyLog {
        let todayStart = TrackingDay.today()
        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.date == todayStart })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let log = DailyLog(date: todayStart)
        let kinds: [TaskKind] = log.isWorkoutDay
            ? [.medication, .gymPrep, .supplement, .morningReview]
            : [.medication, .supplement, .morningReview]
        for kind in kinds {
            log.completions.append(TaskCompletion(kind: kind))
        }
        context.insert(log)
        try? context.save()
        return log
    }

    func markComplete(_ completion: TaskCompletion, photoFileName: String?, dailyLog: DailyLog, context: ModelContext) {
        completion.completedAt = .now
        if let photoFileName {
            let photo = ProgressPhoto(fileName: photoFileName, albumKey: completion.kind.albumKey, takenAt: .now)
            photo.dailyLog = dailyLog
            dailyLog.photos.append(photo)
            completion.photoID = photo.id
        }
        try? context.save()
        recomputeStreak(context: context)
    }

    func recomputeStreak(context: ModelContext) {
        var descriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 365
        guard let logs = try? context.fetch(descriptor) else { streak = 0; return }
        var count = 0
        for log in logs {
            if log.isComplete { count += 1 } else { break }
        }
        streak = count
    }
}
