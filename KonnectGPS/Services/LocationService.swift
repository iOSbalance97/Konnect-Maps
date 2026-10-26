import Combine
import CoreLocation
import UIKit

/// Servicio de ubicación: permisos, posición y rumbo.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var heading: CLHeading?
    @Published var status: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.headingFilter = 5
        manager.activityType = .otherNavigation
        status = manager.authorizationStatus
        requestPermission()
    }

    var isAuthorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }
    var isDenied: Bool { status == .denied || status == .restricted }

    var statusText: String {
        switch status {
        case .notDetermined: return "Sin decidir"
        case .restricted: return "Restringida"
        case .denied: return "Desactivada"
        case .authorizedWhenInUse: return "Activada (al usar la app)"
        case .authorizedAlways: return "Activada (siempre)"
        @unknown default: return "Desconocido"
        }
    }

    func requestPermission() {
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            startUpdates()
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func startUpdates() {
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if isAuthorized { startUpdates() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Sin ubicación: la app sigue funcionando centrada en Madrid.
    }
}
