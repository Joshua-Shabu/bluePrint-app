//
//  LocationService.swift
//  storeMap
//

import CoreLocation

enum LocationError: Error {
    case permissionDenied
    case permissionRestricted
    case failed(Error)
    case unknown
}

/// Wraps CLLocationManager's callback-based API in async/await: request
/// "when in use" authorization (if not already determined) and then a single
/// current location fix.
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestCurrentLocation() async throws -> CLLocationCoordinate2D {
        try await requestAuthorizationIfNeeded()
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    private func requestAuthorizationIfNeeded() async throws {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return
        case .denied:
            throw LocationError.permissionDenied
        case .restricted:
            throw LocationError.permissionRestricted
        case .notDetermined:
            try await withCheckedThrowingContinuation { continuation in
                authorizationContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        @unknown default:
            throw LocationError.unknown
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard let continuation = self.authorizationContinuation else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.authorizationContinuation = nil
                continuation.resume()
            case .denied:
                self.authorizationContinuation = nil
                continuation.resume(throwing: LocationError.permissionDenied)
            case .restricted:
                self.authorizationContinuation = nil
                continuation.resume(throwing: LocationError.permissionRestricted)
            case .notDetermined:
                break
            @unknown default:
                self.authorizationContinuation = nil
                continuation.resume(throwing: LocationError.unknown)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            guard let continuation = self.locationContinuation else { return }
            self.locationContinuation = nil
            if let coordinate {
                continuation.resume(returning: coordinate)
            } else {
                continuation.resume(throwing: LocationError.unknown)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard let continuation = self.locationContinuation else { return }
            self.locationContinuation = nil
            continuation.resume(throwing: LocationError.failed(error))
        }
    }
}
