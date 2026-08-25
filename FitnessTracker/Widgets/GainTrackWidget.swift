//
//  GainTrackWidget.swift
//  Home Screen & Lock Screen widgets — today's workout target,
//  water bar, and streak. Lives in a WidgetKit extension target
//  (see project.yml) sharing the SwiftData store via an App Group.
//

import WidgetKit
import SwiftUI
import SwiftData

struct GainTrackEntry: TimelineEntry {
    let date: Date
    let muscleGroup: String?
    let streak: Int
    let waterCupsToday: Int
    let weightKg: Double?
    let targetWeightKg: Double
}

private let defaultEntry = GainTrackEntry(date: .now, muscleGroup: "صدر", streak: 12, waterCupsToday: 4, weightKg: 63.5, targetWeightKg: 75)

struct GainTrackTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GainTrackEntry {
        defaultEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (GainTrackEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GainTrackEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func fetchEntry() -> GainTrackEntry {
        // Reads from the shared App Group SwiftData store configured in
        // FitnessTrackerApp.swift's ModelConfiguration (groupContainer:).
        guard let container = try? ModelContainer(
            for: DailyLog.self, WaterIntakeLog.self, UserGoal.self,
            configurations: ModelConfiguration(groupContainer: .identifier("group.com.gaintrack.app"))
        ) else {
            return defaultEntry
        }
        let context = ModelContext(container)
        let todayStart = TrackingDay.today()
        let logDescriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.date == todayStart })
        let log = try? context.fetch(logDescriptor).first
        let goal = (try? context.fetch(FetchDescriptor<UserGoal>()))?.first ?? UserGoal()

        let waterStart = TrackingDay.start(for: todayStart)
        let waterEnd = TrackingDay.end(for: todayStart)
        let waterLogs = (try? context.fetch(FetchDescriptor<WaterIntakeLog>(
            predicate: #Predicate { $0.timestamp >= waterStart && $0.timestamp < waterEnd }
        ))) ?? []

        var streakDescriptor = FetchDescriptor<DailyLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        streakDescriptor.fetchLimit = 365
        let allLogs = (try? context.fetch(streakDescriptor)) ?? []
        var streak = 0
        for l in allLogs {
            if l.isComplete { streak += 1 } else { break }
        }

        return GainTrackEntry(
            date: .now,
            muscleGroup: WorkoutSplit.muscleGroup(for: Weekday(rawValue: Calendar.current.component(.weekday, from: .now)) ?? .sunday),
            streak: streak,
            waterCupsToday: waterLogs.count,
            weightKg: log?.weightKg,
            targetWeightKg: goal.targetWeightKg
        )
    }
}

struct GainTrackWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GainTrackEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(entry.waterCupsToday), in: 0...8) {
                Image(systemName: "drop.fill")
            } currentValueLabel: {
                Text("\(entry.waterCupsToday)")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(AppTheme.accent)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.muscleGroup ?? "يوم راحة").font(.headline)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                    Text("\(entry.streak) يوم")
                }
                .font(.caption2)
            }

        default:
            ZStack {
                AppTheme.background
                VStack(alignment: .trailing, spacing: 8) {
                    HStack {
                        Image(systemName: "flame.fill").foregroundStyle(AppTheme.warning)
                        Text("\(entry.streak)").bold()
                        Spacer()
                        Text(entry.muscleGroup ?? "راحة").foregroundStyle(AppTheme.accent)
                    }
                    HStack {
                        Image(systemName: "drop.fill").foregroundStyle(AppTheme.accent)
                        Text("\(entry.waterCupsToday)/8")
                        Spacer()
                    }
                    if let weight = entry.weightKg {
                        Text("\(weight, specifier: "%.1f") ➔ \(entry.targetWeightKg, specifier: "%.0f") كجم")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                .padding(12)
                .foregroundStyle(.white)
            }
        }
    }
}

struct GainTrackWidget: Widget {
    let kind = "GainTrackWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GainTrackTimelineProvider()) { entry in
            GainTrackWidgetView(entry: entry)
                .containerBackground(AppTheme.background, for: .widget)
        }
        .configurationDisplayName("GainTrack")
        .description("تمرين اليوم، المية، والستريك")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct GainTrackWidgetBundle: WidgetBundle {
    var body: some Widget {
        GainTrackWidget()
    }
}
