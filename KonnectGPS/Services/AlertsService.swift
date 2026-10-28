import SwiftUI
import CoreLocation
import UIKit

enum AlertKind: String, Codable, CaseIterable, Identifiable {
    case police, accident, traffic, roadworks, hazard, stopped, mobileRadar, weather
    var id: String { rawValue }

    var title: String {
        switch self {
        case .police: return "Policía"
        case .accident: return "Accidente"
        case .traffic: return "Retención"
        case .roadworks: return "Obras"
        case .hazard: return "Peligro en la vía"
        case .stopped: return "Vehículo parado"
        case .mobileRadar: return "Radar móvil"
        case .weather: return "Mal tiempo"
        }
    }
    var icon: String {
        switch self {
        case .police: return "shield.lefthalf.filled"
        case .accident: return "exclamationmark.triangle.fill"
        case .traffic: return "car.2.fill"
        case .roadworks: return "hammer.fill"
        case .hazard: return "exclamationmark.octagon.fill"
        case .stopped: return "car.fill"
        case .mobileRadar: return "camera.fill"
        case .weather: return "cloud.rain.fill"
        }
    }
    var color: Color {
        switch self {
        case .police: return Color.blue
        case .accident: return Color.red
        case .traffic: return Color.orange
        case .roadworks: return Color.yellow
        case .hazard: return Color(red: 1.0, green: 0.45, blue: 0.2)
        case .stopped: return Color.indigo
        case .mobileRadar: return Color.red
        case .weather: return Color.cyan
        }
    }
    /// Cuánto tiempo se mantiene visible sin que nadie lo confirme.
    var lifetime: TimeInterval {
        switch self {
        case .police: return 2 * 3600
        case .accident: return 3 * 3600
        case .traffic: return 3600
        case .roadworks: return 24 * 3600
        case .hazard: return 3 * 3600
        case .stopped: return 5400
        case .mobileRadar: return 2 * 3600
        case .weather: return 3 * 3600
        }
    }
}

struct RoadAlert: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: AlertKind
    var latitude: Double
    var longitude: Double
    var createdAt: Date
    var confirmations: Int = 0

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > kind.lifetime
    }
}

/// Punto de conexión para compartir avisos entre conductores (servidor propio).
protocol AlertsBackend {
    func fetch(near coordinate: CLLocationCoordinate2D) async -> [RoadAlert]
    func send(_ alert: RoadAlert) async
}

/// Sin servidor: los avisos solo existen en este iPhone.
struct LocalAlertsBackend: AlertsBackend {
    func fetch(near coordinate: CLLocationCoordinate2D) async -> [RoadAlert] { [] }
    func send(_ alert: RoadAlert) async {}
}

@MainActor
final class AlertsService: ObservableObject {
    private static let storageKey = "road_alerts_v1"

    @Published private(set) var alerts: [RoadAlert] = []
    private let backend: AlertsBackend = LocalAlertsBackend()

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let list = try? JSONDecoder().decode([RoadAlert].self, from: data) {
            alerts = list.filter { !$0.isExpired }
        }
    }

    var active: [RoadAlert] { alerts.filter { !$0.isExpired } }

    func report(_ kind: AlertKind, at coordinate: CLLocationCoordinate2D) {
        // Si ya hay uno igual muy cerca, se confirma en vez de duplicar.
        if let existing = active.first(where: { $0.kind == kind && metersBetween($0.coordinate, coordinate) < 80 }) {
            confirm(existing)
            return
        }
        let alert = RoadAlert(kind: kind, latitude: coordinate.latitude, longitude: coordinate.longitude, createdAt: Date())
        alerts.append(alert)
        persist()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let backend = self.backend
        Task { await backend.send(alert) }
    }

    /// "Sigue ahí": renueva el aviso.
    func confirm(_ alert: RoadAlert) {
        guard let index = alerts.firstIndex(where: { $0.id == alert.id }) else { return }
        alerts[index].createdAt = Date()
        alerts[index].confirmations += 1
        persist()
    }

    /// "Ya no está": se elimina.
    func dismiss(_ alert: RoadAlert) {
        alerts.removeAll { $0.id == alert.id }
        persist()
    }

    func syncNearby(_ coordinate: CLLocationCoordinate2D) async {
        let remote = await backend.fetch(near: coordinate)
        guard !remote.isEmpty else { return }
        for alert in remote where !alerts.contains(where: { $0.id == alert.id }) {
            alerts.append(alert)
        }
        persist()
    }

    private func persist() {
        alerts = alerts.filter { !$0.isExpired }
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
