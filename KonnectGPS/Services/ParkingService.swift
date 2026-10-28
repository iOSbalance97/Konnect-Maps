import SwiftUI
import Combine
import AVFoundation
import CoreLocation
import UIKit

/// Coche aparcado: se guarda al desconectarse del Bluetooth/CarPlay del coche,
/// o al alejarte del último punto donde estuvo conectado.
@MainActor
final class ParkingService: ObservableObject {
    private struct Tracking: Codable {
        var latitude: Double
        var longitude: Double
        var date: Date
        var drove: Bool      // se circuló a velocidad de coche durante la conexión
        var pending: Bool    // falta guardar el aparcamiento
    }

    private static let parkedKey = "parked_car_v1"
    private static let trackingKey = "parking_tracking_v1"
    private static let enabledKey = "parking_enabled"

    @Published private(set) var parkedCar: ParkedCar?
    @Published private(set) var carConnected = false
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey) }
    }

    private var tracking: Tracking?
    private var cancellables = Set<AnyCancellable>()
    private var lastTrackingSave = Date.distantPast

    init() {
        let defaults = UserDefaults.standard
        isEnabled = (defaults.object(forKey: Self.enabledKey) as? Bool) ?? true
        if let data = defaults.data(forKey: Self.parkedKey) {
            parkedCar = try? JSONDecoder().decode(ParkedCar.self, from: data)
        }
        if let data = defaults.data(forKey: Self.trackingKey) {
            tracking = try? JSONDecoder().decode(Tracking.self, from: data)
        }
    }

    /// Conecta el servicio a la ubicación y a los cambios de ruta de audio.
    func attach(to location: LocationService) {
        guard cancellables.isEmpty else { return }

        location.$location
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in self?.handle(loc) }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.routeChanged() }
            .store(in: &cancellables)

        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        carConnected = Self.isCarRouteActive()
    }

    // MARK: Acciones manuales

    func parkHere(_ location: CLLocation?) {
        guard let location else { return }
        park(at: location.coordinate, reason: "Guardado a mano")
    }

    func clear() {
        parkedCar = nil
        UserDefaults.standard.removeObject(forKey: Self.parkedKey)
    }

    // MARK: Detección

    private static func isCarRouteActive() -> Bool {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let carPorts: [AVAudioSession.Port] = [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio]
        return outputs.contains { carPorts.contains($0.portType) }
    }

    private func routeChanged() {
        let now = Self.isCarRouteActive()
        guard now != carConnected else { return }
        carConnected = now
        guard isEnabled else { return }

        if !now {
            // Desconexión: solo cuenta si se circuló a velocidad de coche (evita auriculares).
            if let t = tracking, t.drove {
                park(at: CLLocationCoordinate2D(latitude: t.latitude, longitude: t.longitude),
                     reason: "Desconexión de Bluetooth/CarPlay")
                tracking?.pending = false
                tracking?.drove = false
                persistTracking(force: true)
            }
        } else {
            tracking?.drove = false   // nueva conexión
        }
    }

    private func handle(_ loc: CLLocation) {
        guard isEnabled, loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 100 else { return }

        if carConnected {
            var t = tracking ?? Tracking(latitude: loc.coordinate.latitude,
                                         longitude: loc.coordinate.longitude,
                                         date: Date(), drove: false, pending: false)
            t.latitude = loc.coordinate.latitude
            t.longitude = loc.coordinate.longitude
            t.date = Date()
            if loc.speed >= 5 { t.drove = true }
            t.pending = t.drove
            tracking = t
            persistTracking(force: false)
        } else if let t = tracking, t.pending {
            let there = CLLocation(latitude: t.latitude, longitude: t.longitude)
            let away = loc.distance(from: there) > 120
            let old = Date().timeIntervalSince(t.date) > 180
            if away || old {
                park(at: there.coordinate,
                     reason: away ? "Te alejaste del Bluetooth/CarPlay" : "Bluetooth/CarPlay desconectado")
                tracking?.pending = false
                tracking?.drove = false
                persistTracking(force: true)
            }
        }
    }

    private func park(at coordinate: CLLocationCoordinate2D, reason: String) {
        let car = ParkedCar(latitude: coordinate.latitude, longitude: coordinate.longitude,
                            date: Date(), reason: reason)
        parkedCar = car
        if let data = try? JSONEncoder().encode(car) {
            UserDefaults.standard.set(data, forKey: Self.parkedKey)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func persistTracking(force: Bool) {
        if !force && Date().timeIntervalSince(lastTrackingSave) < 5 { return }
        lastTrackingSave = Date()
        if let tracking, let data = try? JSONEncoder().encode(tracking) {
            UserDefaults.standard.set(data, forKey: Self.trackingKey)
        }
    }
}
