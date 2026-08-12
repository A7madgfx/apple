import Foundation
import CoreLocation
import Combine

enum LocationError: LocalizedError {
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "تعذر تحديد موقعك. يرجى تفعيل خدمات الموقع من الإعدادات."
        case .unavailable: return "تعذر تحديد موقعك. يرجى المحاولة مرة أخرى."
        }
    }
}

protocol LocationServicing: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization()
    /// Returns the current location once, without continuous tracking (battery friendly).
    func currentLocation() async throws -> CLLocation
    /// True if `newLocation` differs from `oldLocation` by more than the significant-change threshold (~ a few km).
    func hasSignificantChange(from oldLocation: CLLocation?, to newLocation: CLLocation) -> Bool
}

final class LocationService: NSObject, LocationServicing, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private let significantChangeMeters: CLLocationDistance = 5000

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func currentLocation() async throws -> CLLocation {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func hasSignificantChange(from oldLocation: CLLocation?, to newLocation: CLLocation) -> Bool {
        guard let old = oldLocation else { return true }
        return old.distance(from: newLocation) > significantChangeMeters
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: LocationError.unavailable)
        continuation = nil
    }
}
