//
//  BackupService.swift
//  Manual local backup export/import, complementing the automatic
//  iCloud/CloudKit sync configured on the SwiftData ModelContainer.
//

import Foundation
import SwiftData
import ZIPFoundation

/// A portable snapshot: JSON metadata + the private photo library, zipped.
struct BackupService {
    struct Snapshot: Codable {
        var goal: UserGoalDTO
        var logs: [DailyLogDTO]
        var exportedAt: Date
    }

    struct UserGoalDTO: Codable {
        var startWeightKg: Double, targetWeightKg: Double, heightCm: Double, startDate: Date
    }

    struct DailyLogDTO: Codable {
        var date: Date, isComplete: Bool, weightKg: Double?
        var completions: [String: Date?]   // TaskKind.rawValue -> completedAt
        var photoFileNames: [String]
    }

    /// Exports all local data + photos into a single .gaintrackbackup zip in
    /// the Files app-accessible location the caller provides.
    static func exportBackup(context: ModelContext, to destinationDirectory: URL) throws -> URL {
        let goals = try context.fetch(FetchDescriptor<UserGoal>())
        let logs = try context.fetch(FetchDescriptor<DailyLog>())
        guard let goal = goals.first else { throw BackupError.noGoalConfigured }

        let snapshot = Snapshot(
            goal: UserGoalDTO(startWeightKg: goal.startWeightKg, targetWeightKg: goal.targetWeightKg,
                               heightCm: goal.heightCm, startDate: goal.startDate),
            logs: logs.map { log in
                DailyLogDTO(
                    date: log.date, isComplete: log.isComplete, weightKg: log.weightKg,
                    completions: Dictionary(uniqueKeysWithValues: log.completions.map { ($0.kind.rawValue, $0.completedAt) }),
                    photoFileNames: log.photos.map(\.fileName)
                )
            },
            exportedAt: .now
        )

        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        let jsonURL = workDir.appendingPathComponent("snapshot.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(snapshot).write(to: jsonURL)

        let photosDir = workDir.appendingPathComponent("photos", isDirectory: true)
        try FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        for log in logs {
            for photo in log.photos {
                let src = PhotoStorageService.shared.url(for: photo.fileName)
                let dst = photosDir.appendingPathComponent(photo.fileName)
                if FileManager.default.fileExists(atPath: src.path) {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
            }
        }

        let zipURL = destinationDirectory.appendingPathComponent("GainTrack_Backup_\(Int(Date.now.timeIntervalSince1970)).gaintrackbackup")
        try FileManager.default.zipItem(at: workDir, to: zipURL, shouldKeepParent: false)
        try? FileManager.default.removeItem(at: workDir)
        return zipURL
    }

    /// Restores a snapshot into the given context, importing photos back
    /// into private storage. Existing data with the same tracking-day date
    /// is overwritten.
    static func importBackup(from zipURL: URL, context: ModelContext) throws {
        let workDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        try FileManager.default.unzipItem(at: zipURL, to: workDir)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try Data(contentsOf: workDir.appendingPathComponent("snapshot.json"))
        let snapshot = try decoder.decode(Snapshot.self, from: data)

        let goals = try context.fetch(FetchDescriptor<UserGoal>())
        let goal = goals.first ?? UserGoal()
        goal.startWeightKg = snapshot.goal.startWeightKg
        goal.targetWeightKg = snapshot.goal.targetWeightKg
        goal.heightCm = snapshot.goal.heightCm
        goal.startDate = snapshot.goal.startDate
        if goals.isEmpty { context.insert(goal) }

        let photosDir = workDir.appendingPathComponent("photos", isDirectory: true)

        for dto in snapshot.logs {
            let log = DailyLog(date: dto.date)
            log.isComplete = dto.isComplete
            log.weightKg = dto.weightKg
            for (kindRaw, completedAt) in dto.completions {
                guard let kind = TaskKind(rawValue: kindRaw) else { continue }
                let completion = TaskCompletion(kind: kind)
                completion.completedAt = completedAt ?? nil
                log.completions.append(completion)
            }
            for fileName in dto.photoFileNames {
                let src = photosDir.appendingPathComponent(fileName)
                let dst = PhotoStorageService.shared.url(for: fileName)
                if FileManager.default.fileExists(atPath: src.path) {
                    try? FileManager.default.copyItem(at: src, to: dst)
                }
                let albumKey = fileName.split(separator: "_").first.map(String.init) ?? "morning"
                log.photos.append(ProgressPhoto(fileName: fileName, albumKey: albumKey, takenAt: dto.date))
            }
            context.insert(log)
        }

        try? FileManager.default.removeItem(at: workDir)
        try context.save()
    }

    enum BackupError: Error { case noGoalConfigured }
}
