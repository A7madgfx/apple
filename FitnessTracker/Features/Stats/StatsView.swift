//
//  StatsView.swift
//  Weight tracking, adherence analytics, PDF report generator.
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query private var goals: [UserGoal]
    @State private var reportRange: ReportRange = .weekly
    @State private var generatedReportURL: URL?
    @State private var isGenerating = false

    private var goal: UserGoal? { goals.first }

    private var weightPoints: [(Date, Double)] {
        logs.compactMap { log in log.weightKg.map { (log.date, $0) } }
    }

    private var adherence: Double {
        guard !logs.isEmpty else { return 0 }
        return Double(logs.filter(\.isComplete).count) / Double(logs.count) * 100
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    weightChartCard
                    adherenceCard
                    reportCard
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("الإحصائيات")
        }
    }

    @ViewBuilder
    private var weightChartCard: some View {
        if let goal {
            CardView {
                Text("منحنى الوزن")
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.textPrimary)

                Chart {
                    ForEach(weightPoints, id: \.0) { point in
                        LineMark(x: .value("التاريخ", point.0), y: .value("الوزن", point.1))
                            .foregroundStyle(AppTheme.accent)
                            .interpolationMethod(.catmullRom)
                        PointMark(x: .value("التاريخ", point.0), y: .value("الوزن", point.1))
                            .foregroundStyle(AppTheme.accent)
                    }
                    RuleMark(y: .value("الهدف", goal.targetWeightKg))
                        .foregroundStyle(AppTheme.warning)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("الهدف \(goal.targetWeightKg, specifier: "%.0f") كجم")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.warning)
                        }
                }
                .chartYScale(domain: (goal.startWeightKg - 2)...(goal.targetWeightKg + 2))
                .frame(height: 220)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var adherenceCard: some View {
        CardView {
            Text("الالتزام")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            HStack {
                Text("\(Int(adherence))٪")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(logs.filter(\.isComplete).count) من \(logs.count) يوم")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .font(.footnote)
        }
    }

    private var reportCard: some View {
        CardView {
            Text("تقرير PDF")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)

            Picker("المدى", selection: $reportRange) {
                Text("أسبوعي").tag(ReportRange.weekly)
                Text("شهري").tag(ReportRange.monthly)
            }
            .pickerStyle(.segmented)

            Button {
                generateReport()
            } label: {
                HStack {
                    if isGenerating { ProgressView().tint(.black) }
                    Text("إنشاء التقرير")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isGenerating)

            if let generatedReportURL {
                ShareLink(item: generatedReportURL) {
                    Label("مشاركة التقرير", systemImage: "square.and.arrow.up")
                        .foregroundStyle(AppTheme.accent)
                }
            }
        }
    }

    private func generateReport() {
        guard let goal else { return }
        isGenerating = true
        Task {
            let url = PDFReportGenerator.generate(range: reportRange, logs: logs, goal: goal)
            await MainActor.run {
                generatedReportURL = url
                isGenerating = false
            }
        }
    }
}
