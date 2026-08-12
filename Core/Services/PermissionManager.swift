import Foundation
import AVFoundation
import UserNotifications
import CoreLocation
import UIKit

/// Requests each iOS permission separately and contextually — never bundled — and always
/// with an Arabic explanation shown in-app before the system prompt (see onboarding /
/// feature screens for the copy). This type only wraps the system check + request calls.
@MainActor
final class PermissionManager: ObservableObject {
    @Published var locationStatus: CLAuthorizationStatus = CLLocationManager().authorizationStatus
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    @Published var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    private let locationService: LocationServicing

    init(locationService: LocationServicing) {
        self.locationService = locationService
    }

    func refreshAll() async {
        locationStatus = locationService.authorizationStatus
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    func requestLocation() {
        locationService.requestWhenInUseAuthorization()
    }

    @discardableResult
    func requestNotifications() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAll()
            return granted
        } catch {
            return false
        }
    }

    /// Requested contextually, only right before the camera screen opens (never on first launch).
    @discardableResult
    func requestCamera() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        await refreshAll()
        return granted
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
