//
//  TaskPhotoCameraView.swift
//  Generic photo-verification camera used by Medication / Gym prep / Supplement tasks.
//

import SwiftUI

struct TaskPhotoCameraView: View {
    let kind: TaskKind
    let onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraService()
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            CameraPreviewView(session: camera.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.5), in: Circle())
                    }
                    Spacer()
                    Text(kind.titleAR)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.black.opacity(0.5), in: Capsule())
                }
                .padding()
                Spacer()

                Button {
                    Task { await capture() }
                } label: {
                    Circle()
                        .strokeBorder(AppTheme.accent, lineWidth: 4)
                        .frame(width: 76, height: 76)
                        .overlay(Circle().fill(isCapturing ? AppTheme.accent.opacity(0.4) : .clear))
                }
                .disabled(isCapturing)
                .padding(.bottom, 40)
            }
        }
        .background(Color.black)
        .onAppear { camera.configure(); camera.start() }
        .onDisappear { camera.stop() }
    }

    private func capture() async {
        isCapturing = true
        defer { isCapturing = false }
        guard let image = await camera.capturePhoto() else { return }
        if let fileName = try? PhotoStorageService.shared.save(image, albumKey: kind.albumKey) {
            onSaved(fileName)
            dismiss()
        }
    }
}
