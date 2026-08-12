import AVFoundation
import UIKit

enum CameraError: LocalizedError {
    case permissionDenied
    case unavailable
    case captureFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "تعذر الوصول إلى الكاميرا. يرجى منح الإذن من الإعدادات."
        case .unavailable: return "تعذر الوصول إلى الكاميرا على هذا الجهاز."
        case .captureFailed: return "تعذر التقاط الصورة، حاول مرة أخرى."
        }
    }
}

/// Thin wrapper around AVCaptureSession for the prayer-mat verification flow.
/// Photos are processed entirely on-device and never persisted or uploaded (see
/// PrayerMatRecognitionService) — this service exposes the raw pixel buffer to the
/// recognition pipeline and nothing else.
final class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var captureContinuation: CheckedContinuation<UIImage, Error>?

    func configureIfNeeded() throws {
        guard session.inputs.isEmpty else { return }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw CameraError.permissionDenied
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        session.beginConfiguration()
        session.sessionPreset = .photo
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        } catch {
            session.commitConfiguration()
            throw CameraError.unavailable
        }
        session.commitConfiguration()
    }

    func start() {
        guard !session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        Task.detached(priority: .userInitiated) { [session] in
            session.stopRunning()
        }
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            self.captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            captureContinuation?.resume(throwing: error)
            captureContinuation = nil
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            captureContinuation?.resume(throwing: CameraError.captureFailed)
            captureContinuation = nil
            return
        }
        captureContinuation?.resume(returning: image)
        captureContinuation = nil
    }
}
