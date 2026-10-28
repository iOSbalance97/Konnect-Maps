import Combine
import CoreLocation
import UIKit

/// El rumbo se publica aparte para que solo se redibuje el punto del usuario.
final class HeadingStore: ObservableObject {
    @Published var degrees: Double = 0
}

/// Servicio de ubicación: permisos, precisión, posición, rumbo y segundo plano.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    let headingStore = HeadingStore()
    private var navigating = false

    @Published var location: CLLocation?
    @Published var status: CLAuthorizationStatus = .notDetermined
    @Published var accuracy: CLAccuracyAuthorization = .fullAccuracy

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.headingFilter = 3
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        status = manager.authorizationStatus
        accuracy = manager.accuracyAuthorization
        requestPermission()
    }

    var isAuthorized: Bool { status == .authorizedWhenInUse || status == .authorizedAlways }
    var isAlways: Bool { status == .authorizedAlways }
    var isDenied: Bool { status == .denied || status == .restricted }
    /// El usuario concedió solo la ubicación aproximada (sale un área grande en vez de un punto).
    var isReduced: Bool { isAuthorized && accuracy == .reducedAccuracy }

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

    var accuracyText: String { accuracy == .fullAccuracy ? "Precisa" : "Aproximada" }

    func requestPermission() {
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAuthorized {
            startUpdates()
        }
    }

    /// Permiso "Siempre": necesario para detectar el coche aparcado en segundo plano.
    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    /// Pide ubicación precisa (si el usuario solo dio la aproximada).
    func requestFullAccuracy() {
        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "Navegacion") { [weak self] error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.accuracy = self.manager.accuracyAuthorization
                if error != nil { self.openSettings() }
            }
        }
    }

    /// Más precisión y frecuencia mientras se navega.
    func setNavigating(_ on: Bool) {
        navigating = on
        manager.desiredAccuracy = on ? kCLLocationAccuracyBestForNavigation : kCLLocationAccuracyBest
        manager.distanceFilter = on ? kCLDistanceFilterNone : 3
        manager.activityType = on ? .automotiveNavigation : .otherNavigation
        applyBackgroundConfig()
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
        applyBackgroundConfig()
    }

    /// Segundo plano: solo si el modo "location" está declarado en el Info.plist.
    private func applyBackgroundConfig() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String]
        guard modes?.contains("location") == true else { return }
        manager.allowsBackgroundLocationUpdates = isAlways || navigating
        manager.showsBackgroundLocationIndicator = navigating
        if isAlways && CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        accuracy = manager.accuracyAuthorization
        if isAuthorized { startUpdates() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let best = locations.last(where: { $0.horizontalAccuracy >= 0 }) {
            location = best
        }
        accuracy = manager.accuracyAuthorization
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        headingStore.degrees = value
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Sin ubicación: la app sigue funcionando centrada en Madrid.
    }
}
