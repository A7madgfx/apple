//
//  MorningReviewCameraView.swift
//  The 5:00 AM Quick Snap flow: translucent positioning overlay for
//  consistent framing across days, then a lightweight weight keypad,
//  then the daily review summary.
//

import SwiftUI
import SwiftData

struct MorningReviewCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @StateObject private var camera = CameraService()
    @StateObject private var viewModel = TodayViewModel()

    @State private var capturedImage: UIImage?
    @State private var stage: Stage = .camera
    @State private var weightText: String = ""

    enum Stage { case camera, weightEntry, review }

    var body: some View {
        ZStack {
            switch stage {
            case .camera: cameraStage
            case .weightEntry: weightEntryStage
            case .review: reviewStage
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: Camera + overlay

    private var cameraStage: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            // Translucent silhouette / positioning guide for consistent framing.
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 40)
                    .strokeBorder(AppTheme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .frame(width: geo.size.width * 0.6, height: geo.size.height * 0.75)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .allowsHitTesting(false)

            VStack {
                Text("راجعة الصباح 📸")
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.top, 12)
                Spacer()
                Button {
                    Task { await capture() }
                } label: {
                    Circle()
                        .strokeBorder(AppTheme.accent, lineWidth: 4)
                        .frame(width: 80, height: 80)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { camera.configure(); camera.start() }
        .onDisappear { camera.stop() }
    }

    private func capture() async {
        guard let image = await camera.capturePhoto() else { return }
        capturedImage = image
        camera.stop()
        withAnimation { stage = .weightEntry }
    }

    // MARK: Weight keypad

    private var weightEntryStage: some View {
        VStack(spacing: 24) {
            Spacer()
            if let capturedImage {
                Image(uiImage: capturedImage)
                    .resizable().scaledToFit()
                    .frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .opacity(0.4)
            }
            Text("سجل وزنك النهاردة")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text(weightText.isEmpty ? "0.0" : weightText)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.accent)
            NumericKeypad(text: $weightText)
            Button {
                finishReview()
            } label: {
                Text("حفظ")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(Double(weightText) == nil)
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func finishReview() {
        guard let weight = Double(weightText), let image = capturedImage else { return }
        let log = viewModel.ensureTodayLog(context: context)
        if let fileName = try? PhotoStorageService.shared.save(image, albumKey: "morning") {
            let photo = ProgressPhoto(fileName: fileName, albumKey: "morning", takenAt: .now, weightKg: weight)
            photo.dailyLog = log
            log.photos.append(photo)
            log.weightKg = weight
            if let completion = log.completion(for: .morningReview) {
                completion.completedAt = .now
                completion.photoID = photo.id
            }
            log.isComplete = log.completions.allSatisfy(\.isDone)
            log.reviewedAt = .now
            try? context.save()
        }
        withAnimation { stage = .review }
    }

    // MARK: Review summary

    private var reviewStage: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(AppTheme.accent)
            Text("تمام كده! يوم مكتمل ✅")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Text("استمر كده وهتوصل للهدف")
                .foregroundStyle(AppTheme.textSecondary)
            Button {
                dismiss()
            } label: {
                Text("تم")
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

private struct NumericKeypad: View {
    @Binding var text: String
    private let rows: [[String]] = [["1","2","3"],["4","5","6"],["7","8","9"],[".","0","⌫"]]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            tap(key)
                        } label: {
                            Text(key)
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 72, height: 56)
                                .background(AppTheme.cardElevated, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
    }

    private func tap(_ key: String) {
        switch key {
        case "⌫": if !text.isEmpty { text.removeLast() }
        case ".": if !text.contains(".") { text += key }
        default: if text.count < 5 { text += key }
        }
    }
}
