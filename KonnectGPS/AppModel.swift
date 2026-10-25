import SwiftUI
import MapKit
import CoreLocation

enum AppTab: Hashable { case explore, saved, profile }

@MainActor
final class AppModel: ObservableObject {
    private static let savedKey = "saved_places"
    private static let recentsKey = "recent_searches"

    @Published var tab: AppTab = .explore

    // Búsqueda y resultados
    @Published var places: [Place] = []
    @Published var selectedPlace: Place?
    @Published var activeCategory: PlaceCategory?
    @Published var recents: [String] { didSet { UserDefaults.standard.set(recents, forKey: Self.recentsKey) } }

    // Guardados
    @Published var saved: [SavedPlace] {
        didSet {
            if let data = try? JSONEncoder().encode(saved) {
                UserDefaults.standard.set(data, forKey: Self.savedKey)
            }
        }
    }

    // Navegación
    @Published var destination: Place?
    @Published var routes: [RouteMode: RouteInfo] = [:]
    @Published var mode: RouteMode = .driving
    @Published var isNavigating = false
    @Published var isLoadingRoutes = false
    @Published var routeVersion = 0

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.savedKey),
           let list = try? JSONDecoder().decode([SavedPlace].self, from: data) {
            saved = list
        } else {
            saved = []
        }
        recents = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
    }

    // MARK: Búsqueda

    func query(_ text: String, near center: CLLocationCoordinate2D) async -> [Place] {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return [] }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = t
        request.region = MKCoordinateRegion(center: center, latitudinalMeters: 8000, longitudinalMeters: 8000)
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.map { Place(mapItem: $0) }
    }

    func toggleCategory(_ category: PlaceCategory, near center: CLLocationCoordinate2D) async {
        if activeCategory == category {
            activeCategory = nil
            places = []
        } else {
            activeCategory = category
            places = await query(category.query, near: center)
        }
    }

    func clearResults() {
        places = []
        activeCategory = nil
    }

    func addRecent(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        recents.removeAll { $0.caseInsensitiveCompare(t) == .orderedSame }
        recents.insert(t, at: 0)
        if recents.count > 8 { recents = Array(recents.prefix(8)) }
    }

    // MARK: Guardados

    func isSaved(_ place: Place) -> Bool { saved.contains { $0.id == place.key } }

    func toggleSaved(_ place: Place) {
        if let index = saved.firstIndex(where: { $0.id == place.key }) {
            saved.remove(at: index)
        } else {
            saved.insert(SavedPlace(place), at: 0)
        }
    }

    // MARK: Rutas

    func startRoute(to place: Place, from origin: CLLocationCoordinate2D) async {
        tab = .explore
        selectedPlace = nil
        destination = place
        isNavigating = false
        routes = [:]
        isLoadingRoutes = true

        var result: [RouteMode: RouteInfo] = [:]
        for m in RouteMode.allCases {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
            request.destination = place.mapItem
            request.transportType = m.transportType
            let directions = MKDirections(request: request)
            if m == .transit {
                if let eta = try? await directions.calculateETA() {
                    result[m] = RouteInfo(time: eta.expectedTravelTime, distance: eta.distance, route: nil)
                }
            } else if let route = try? await directions.calculate().routes.first {
                result[m] = RouteInfo(time: route.expectedTravelTime, distance: route.distance, route: route)
            }
        }

        guard destination?.id == place.id else { return }   // el usuario cerró mientras cargaba
        routes = result
        if result[mode] == nil, let first = RouteMode.allCases.first(where: { result[$0] != nil }) {
            mode = first
        }
        isLoadingRoutes = false
        routeVersion += 1
    }

    func stopRoute() {
        destination = nil
        routes = [:]
        isNavigating = false
        isLoadingRoutes = false
    }
}
