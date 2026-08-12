import SwiftUI
import AVFoundation

struct PrayerMatCameraView: View {
    let alarm: ActivePrayerAlarm
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: PrayerMatVerificationViewModel

    init(alarm: ActivePrayerAlarm, appState: AppState) {
        self.alarm = alarm
        _viewModel = StateObject(wrappedValue: PrayerMatVerificationViewModel(
            cameraService: appState.cameraService,
            recognitionService: appState.recognitionService,
            permissionManager: appState.permissionManager
        ))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreviewView(session: appState.cameraService.session)
                .ignoresSafeArea()
                .overlay(matFrameOverlay)

            VStack {
                topBar
                Spacer()
                bottomPanel
            }
        }
        .task {
            await viewModel.prepare()
        }
        .onDisappear { viewModel.stop() }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Text("صوّر سجادة الصلاة وهي ممددة على الأرض")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
                .padding(12)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding()
    }

    private var matFrameOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(AppTheme.primaryYellow.opacity(0.8), style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
            .padding(40)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var bottomPanel: some View {
        VStack(spacing: 16) {
            switch viewModel.phase {
            case .ready, .capturing:
                Button {
                    Task {
                        let success = await viewModel.captureAndVerify()
                        if success {
                            try? await Task.sleep(nanoseconds: 900_000_000)
                            appState.markPrayerCompleted()
                        }
                    }
                } label: {
                    Circle()
                        .fill(AppTheme.primaryYellow)
                        .frame(width: 76, height: 76)
                        .overlay(Circle().stroke(.white, lineWidth: 4).padding(4))
                }
                .disabled(viewModel.phase == .capturing || viewModel.cameraPermissionDenied)

            case .verifying:
                ProgressView().tint(AppTheme.primaryYellow)
                Text("جارٍ التحقق من الصورة...").foregroundStyle(.white)

            case .success:
                Label("تم التحقق من سجادة الصلاة", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.success)

            case .failed(let message):
                VStack(spacing: 10) {
                    Text(message)
                        .foregroundStyle(AppTheme.error)
                        .multilineTextAlignment(.center)
                    Text("حاول تصوير السجادة كاملة وبإضاءة واضحة")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Button {
                        viewModel.reset()
                    } label: {
                        Text("إعادة التصوير")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(AppTheme.primaryYellow, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 24)
                }
            }

            if viewModel.cameraPermissionDenied {
                Button("فتح الإعدادات لتفعيل الكاميرا") { appState.permissionManager.openSystemSettings() }
                    .foregroundStyle(AppTheme.primaryYellow)
            }
        }
        .padding(.bottom, 40)
    }
}

extension PrayerMatVerificationViewModel.Phase: Equatable {
    static func == (lhs: PrayerMatVerificationViewModel.Phase, rhs: PrayerMatVerificationViewModel.Phase) -> Bool {
        switch (lhs, rhs) {
        case (.ready, .ready), (.capturing, .capturing), (.verifying, .verifying), (.success, .success): return true
        case (.failed, .failed): return true
        default: return false
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
