//
//  AppShortcuts.swift
//  Siri Shortcuts integration for quick voice logging ("Log Water", etc.)
//

import AppIntents
import SwiftData

struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "سجّل مية"
    static var description = IntentDescription("يسجل كوب مية (250 مل) في اليوم الحالي.")

    @Parameter(title: "الكمية (مل)", default: 250)
    var amountMl: Int

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: WaterIntakeLog.self)
        let context = ModelContext(container)
        context.insert(WaterIntakeLog(amountMl: amountMl))
        try context.save()
        return .result(dialog: "تم تسجيل \(amountMl) مل مية 💧")
    }
}

struct LogWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "سجّل وزنك"
    static var description = IntentDescription("يسجل وزن اليوم في المتابعة.")

    @Parameter(title: "الوزن (كجم)")
    var weightKg: Double

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try ModelContainer(for: DailyLog.self, TaskCompletion.self, ProgressPhoto.self, UserGoal.self)
        let context = ModelContext(container)
        let todayStart = TrackingDay.today()
        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.date == todayStart })
        let log = try context.fetch(descriptor).first ?? {
            let new = DailyLog(date: todayStart)
            context.insert(new)
            return new
        }()
        log.weightKg = weightKg
        try context.save()
        return .result(dialog: "تم تسجيل الوزن \(weightKg, format: .number) كجم")
    }
}

struct GainTrackShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: ["سجل مية في \(.applicationName)", "Log water in \(.applicationName)"],
            shortTitle: "سجّل مية",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: LogWeightIntent(),
            phrases: ["سجل وزني في \(.applicationName)", "Log my weight in \(.applicationName)"],
            shortTitle: "سجّل الوزن",
            systemImageName: "scalemass.fill"
        )
    }
}
