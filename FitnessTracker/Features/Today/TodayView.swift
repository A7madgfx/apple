//
//  TodayView.swift
//  Dashboard & daily timeline (17:00 → 05:00 tracking day).
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [UserGoal]
    @StateObject private var viewModel = TodayViewModel()
    @State private var dailyLog: DailyLog?
    @State private var showCamera: TaskKind?

    private var goal: UserGoal? { goals.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let log = dailyLog {
                        headerCard(log: log)
                        weightProgressCard
                        timelineCard(log: log)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("اليوم")
            .onAppear {
                dailyLog = viewModel.ensureTodayLog(context: context)
                viewModel.recomputeStreak(context: context)
            }
            .fullScreenCover(item: $showCamera) { kind in
                TaskPhotoCameraView(kind: kind) { fileName in
                    if let log = dailyLog, let completion = log.completion(for: kind) {
                        viewModel.markComplete(completion, photoFileName: fileName, dailyLog: log, context: context)
                    }
                }
            }
        }
    }

    // MARK: Header

    @ViewBuilder
    private func headerCard(log: DailyLog) -> some View {
        CardView {
            HStack {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(log.muscleGroup.map { "تمرين اليوم: \($0)" } ?? "يوم راحة")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(TrackingDay.start(for: log.date).formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(AppTheme.warning)
                    Text("\(viewModel.streak)")
                        .font(.title3.bold())
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("يوم متتالي")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: Weight progress

    @ViewBuilder
    private var weightProgressCard: some View {
        if let goal {
            CardView {
                Text("هدف الوزن")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)
                WeightProgressBar(goal: goal, currentWeight: latestWeight ?? goal.startWeightKg)
                HStack {
                    Text("\(goal.startWeightKg, specifier: "%.0f") كجم")
                    Spacer()
                    Text("متبقي \(remaining, specifier: "%.1f") كجم")
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Text("\(goal.targetWeightKg, specifier: "%.0f") كجم")
                }
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var latestWeight: Double? { dailyLog?.weightKg }
    private var remaining: Double {
        guard let goal else { return 0 }
        return max(goal.targetWeightKg - (latestWeight ?? goal.startWeightKg), 0)
    }

    // MARK: Timeline

    @ViewBuilder
    private func timelineCard(log: DailyLog) -> some View {
        CardView {
            Text("الجدول الزمني")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)

            ForEach(log.completions.sorted(by: { $0.kind.sortOrder < $1.kind.sortOrder })) { completion in
                TimelineRow(completion: completion) {
                    showCamera = completion.kind
                }
                if completion.id != log.completions.last?.id {
                    Divider().overlay(AppTheme.separator)
                }
            }
        }
    }
}

private extension TaskKind {
    var sortOrder: Int {
        switch self {
        case .medication: return 0
        case .gymPrep: return 1
        case .supplement: return 2
        case .morningReview: return 3
        }
    }

    var icon: String {
        switch self {
        case .medication: return "pills.fill"
        case .gymPrep: return "figure.strengthtraining.traditional"
        case .supplement: return "cup.and.saucer.fill"
        case .morningReview: return "camera.fill"
        }
    }
}

extension TaskKind: Identifiable {}

private struct TimelineRow: View {
    let completion: TaskCompletion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: completion.kind.icon)
                    .foregroundStyle(completion.isDone ? AppTheme.accent : AppTheme.textSecondary)
                    .frame(width: 28)
                Text(completion.kind.titleAR)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                if completion.isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.accent)
                } else {
                    Image(systemName: "camera.circle")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(.vertical, 6)
        }
        .disabled(completion.isDone)
    }
}

private struct WeightProgressBar: View {
    let goal: UserGoal
    let currentWeight: Double

    private var fraction: Double {
        let total = goal.targetWeightKg - goal.startWeightKg
        guard total > 0 else { return 0 }
        return min(max((currentWeight - goal.startWeightKg) / total, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.cardElevated)
                Capsule()
                    .fill(AppTheme.accent)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 10)
    }
}
