//
//  SettingsRoutineView.swift
//  Fixed weekly workout split display + notification preferences + backup.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsRoutineView: View {
    @Environment(\.modelContext) private var context
    @Query private var goals: [UserGoal]
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportedURL: URL?
    @State private var alertMessage: String?

    private var goal: UserGoal? { goals.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    routineCard
                    goalCard
                    backupCard
                }
                .padding(16)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("الإعدادات والجدول")
            .fileExporter(isPresented: $isExporting, document: exportedURL.map(BackupDocument.init),
                          contentType: .data, defaultFilename: "GainTrack_Backup") { _ in }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data]) { result in
                if case .success(let url) = result { importBackup(from: url) }
            }
            .alert("النسخ الاحتياطي", isPresented: .constant(alertMessage != nil), actions: {
                Button("تم") { alertMessage = nil }
            }, message: { Text(alertMessage ?? "") })
        }
    }

    private var routineCard: some View {
        CardView {
            Text("الجدول الأسبوعي الثابت")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            ForEach(weeklySchedule, id: \.day) { entry in
                HStack {
                    Text(entry.day)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(entry.group ?? "راحة")
                        .foregroundStyle(entry.group == nil ? AppTheme.textSecondary : AppTheme.accent)
                }
                .font(.footnote)
                .padding(.vertical, 4)
            }
        }
    }

    private var weeklySchedule: [(day: String, group: String?)] {
        [
            ("الإثنين", "ظهر"), ("الثلاثاء", "زنود"), ("الأربعاء", "صدر"),
            ("الخميس", nil), ("الجمعة", "أكتاف"), ("السبت", "أرجل"), ("الأحد", nil)
        ]
    }

    private var goalCard: some View {
        CardView {
            Text("هدف الوزن")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            if let goal {
                HStack {
                    goalField(title: "البداية", value: Binding(get: { goal.startWeightKg }, set: { goal.startWeightKg = $0; try? context.save() }))
                    goalField(title: "الهدف", value: Binding(get: { goal.targetWeightKg }, set: { goal.targetWeightKg = $0; try? context.save() }))
                    goalField(title: "الطول (سم)", value: Binding(get: { goal.heightCm }, set: { goal.heightCm = $0; try? context.save() }))
                }
            }
        }
    }

    private func goalField(title: String, value: Binding<Double>) -> some View {
        VStack {
            Text(title).font(.caption2).foregroundStyle(AppTheme.textSecondary)
            TextField("", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .padding(8)
                .background(AppTheme.cardElevated, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private var backupCard: some View {
        CardView {
            Text("النسخ الاحتياطي")
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.textPrimary)
            Text("مزامنة تلقائية عبر iCloud، بالإضافة لنسخة احتياطية يدوية.")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Button {
                exportBackup()
            } label: {
                Label("تصدير نسخة احتياطية", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.cardElevated, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Button {
                isImporting = true
            } label: {
                Label("استيراد نسخة احتياطية", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.cardElevated, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(AppTheme.textPrimary)
            }
        }
    }

    private func exportBackup() {
        do {
            let tmpDir = FileManager.default.temporaryDirectory
            let url = try BackupService.exportBackup(context: context, to: tmpDir)
            exportedURL = url
            isExporting = true
        } catch {
            alertMessage = "فشل التصدير: \(error.localizedDescription)"
        }
    }

    private func importBackup(from url: URL) {
        do {
            try BackupService.importBackup(from: url, context: context)
            alertMessage = "تم الاستيراد بنجاح"
        } catch {
            alertMessage = "فشل الاستيراد: \(error.localizedDescription)"
        }
    }
}

private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] = [.data]
    let url: URL
    init(url: URL) { self.url = url }
    init(configuration: ReadConfiguration) throws { self.url = URL(fileURLWithPath: "") }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: url)
    }
}
