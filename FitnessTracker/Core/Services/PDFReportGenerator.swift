//
//  PDFReportGenerator.swift
//  Generates a weekly/monthly adherence + weight-chart PDF report.
//

import Foundation
import UIKit
import Charts
import SwiftUI

enum ReportRange {
    case weekly, monthly

    var days: Int { self == .weekly ? 7 : 30 }
    var titleAR: String { self == .weekly ? "تقرير أسبوعي" : "تقرير شهري" }
}

struct PDFReportGenerator {
    /// Builds a PDF summarizing adherence %, streak, weight curve, and a
    /// grid of the tracking-day photos, and returns the file URL.
    @MainActor
    static func generate(range: ReportRange, logs: [DailyLog], goal: UserGoal) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter @72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let cutoff = Calendar.current.date(byAdding: .day, value: -range.days, to: .now)!
        let scoped = logs.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        let completedDays = scoped.filter(\.isComplete).count
        let adherence = scoped.isEmpty ? 0 : Double(completedDays) / Double(scoped.count) * 100

        let data = renderer.pdfData { ctx in
            ctx.beginPage()

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.darkGray
            ]

            (range.titleAR as NSString).draw(at: CGPoint(x: 40, y: 40), withAttributes: titleAttrs)

            let summary = """
            الالتزام: \(Int(adherence))٪  •  الأيام المكتملة: \(completedDays)/\(scoped.count)
            الوزن الحالي: \(scoped.last?.weightKg.map { String(format: "%.1f", $0) } ?? "-") كجم
            الهدف: \(String(format: "%.0f", goal.startWeightKg)) ➔ \(String(format: "%.0f", goal.targetWeightKg)) كجم
            """
            (summary as NSString).draw(in: CGRect(x: 40, y: 80, width: 532, height: 90), withAttributes: bodyAttrs)

            // Simple weight curve drawn manually with Core Graphics.
            drawWeightCurve(scoped: scoped, goal: goal, in: CGRect(x: 40, y: 180, width: 532, height: 220))

            // Photo grid (thumbnails of morning-review photos).
            let photos = scoped.compactMap { $0.photos.first(where: { $0.albumKey == "morning" }) }
            drawPhotoGrid(photos: photos, in: CGRect(x: 40, y: 420, width: 532, height: 320))
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("report_\(UUID().uuidString).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }

    private static func drawWeightCurve(scoped: [DailyLog], goal: UserGoal, in rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()

        UIColor(AppTheme.separator).setStroke()
        let border = UIBezierPath(rect: rect)
        border.lineWidth = 1
        border.stroke()

        let points = scoped.compactMap { log -> (Date, Double)? in
            guard let w = log.weightKg else { return nil }
            return (log.date, w)
        }
        guard points.count > 1 else { ctx.restoreGState(); return }

        let minW = min(goal.startWeightKg, points.map(\.1).min() ?? goal.startWeightKg)
        let maxW = max(goal.targetWeightKg, points.map(\.1).max() ?? goal.targetWeightKg)
        func yFor(_ w: Double) -> CGFloat {
            rect.maxY - CGFloat((w - minW) / (maxW - minW)) * rect.height
        }
        func xFor(_ index: Int) -> CGFloat {
            rect.minX + CGFloat(index) / CGFloat(max(points.count - 1, 1)) * rect.width
        }

        // Target line
        UIColor(AppTheme.warning).setStroke()
        let targetLine = UIBezierPath()
        targetLine.move(to: CGPoint(x: rect.minX, y: yFor(goal.targetWeightKg)))
        targetLine.addLine(to: CGPoint(x: rect.maxX, y: yFor(goal.targetWeightKg)))
        targetLine.lineWidth = 1
        targetLine.setLineDash([4, 3], count: 2, phase: 0)
        targetLine.stroke()

        // Weight curve
        UIColor(AppTheme.accent).setStroke()
        let curve = UIBezierPath()
        curve.move(to: CGPoint(x: xFor(0), y: yFor(points[0].1)))
        for (i, p) in points.enumerated().dropFirst() {
            curve.addLine(to: CGPoint(x: xFor(i), y: yFor(p.1)))
        }
        curve.lineWidth = 2.5
        curve.stroke()

        ctx.restoreGState()
    }

    private static func drawPhotoGrid(photos: [ProgressPhoto], in rect: CGRect) {
        let columns = 6
        let spacing: CGFloat = 6
        let cellSize = (rect.width - CGFloat(columns - 1) * spacing) / CGFloat(columns)

        for (i, photo) in photos.prefix(24).enumerated() {
            guard let image = PhotoStorageService.shared.loadImage(fileName: photo.fileName) else { continue }
            let row = i / columns
            let col = i % columns
            let cellRect = CGRect(
                x: rect.minX + CGFloat(col) * (cellSize + spacing),
                y: rect.minY + CGFloat(row) * (cellSize + spacing),
                width: cellSize, height: cellSize
            )
            image.draw(in: cellRect)
        }
    }
}
