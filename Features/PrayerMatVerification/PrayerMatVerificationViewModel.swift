import Foundation
import UIKit

@MainActor
final class PrayerMatVerificationViewModel: ObservableObject {
    enum Phase { case ready, capturing, verifying, success, failed(String) }

    @Published var phase: Phase = .ready
    @Published var cameraPermissionDenied = false

    private let cameraService: CameraService
    private let recognitionService: PrayerMatRecognitionService
    private let permissionManager: PermissionManager

    init(cameraService: CameraService, recognitionService: PrayerMatRecognitionService, permissionManager: PermissionManager) {
        self.cameraService = cameraService
        self.recognitionService = recognitionService
        self.permissionManager = permissionManager
    }

    func prepare() async {
        if permissionManager.cameraStatus == .notDetermined {
            _ = await permissionManager.requestCamera()
        }
        guard permissionManager.cameraStatus == .authorized else {
            cameraPermissionDenied = true
            return
        }
        do {
            try cameraService.configureIfNeeded()
            cameraService.start()
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? "تعذر الوصول إلى الكاميرا.")
        }
    }

    func stop() {
        cameraService.stop()
    }

    /// Captures a photo, runs on-device recognition, and returns whether verification passed.
    /// The captured UIImage is never written to disk or the photo library and is discarded
    /// immediately after this function returns — no upload occurs anywhere in this path.
    @discardableResult
    func captureAndVerify() async -> Bool {
        phase = .capturing
        do {
            let image = try await cameraService.capturePhoto()
            phase = .verifying
            let result = await recognitionService.verify(image: image)
            if result.isVerified {
                phase = .success
                return true
            } else {
                phase = .failed(result.reasonIfRejected ?? "لم نتمكن من التحقق من سجادة الصلاة")
                return false
            }
        } catch {
            phase = .failed((error as? LocalizedError)?.errorDescription ?? "تعذر التقاط الصورة، حاول مرة أخرى.")
            return false
        }
    }

    func reset() {
        phase = .ready
    }
}
