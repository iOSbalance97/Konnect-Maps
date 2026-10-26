import SwiftUI
import MapKit
import CoreLocation

enum AppTab: Hashable { case explore, profile }

@MainActor
final class AppModel: ObservableObject {
    private static let listsKey = "place_lists_v2"
    private static let legacySavedKey = "saved_places"
    private static let recentsKey = "recent_searches"

    @Published var tab: AppTab = .explore

    // Búsqueda y resultados
    @Published var places: [Place] = []
    @Published var selectedPlace: Place?
    @Published var droppedPin: Place?
    @Published var activeCategory: PlaceCategory?
    @Published var cityName: String?
    @Published var googleMessage: String?
    @Published var recents: [String] {
        didSet { UserDefaults.standard.set(recents, forKey: Self.recentsKey) }
    }

    // Listas: Favoritos, Guardados y Sitios relevantes
    @Published var lists: [String: [SavedPlace]] {
        didSet {
            if let data = try? JSONEncoder().encode(lists) {
                UserDefaults.standard.set(data, forKey: Self.listsKey)
            }
        }
    }

    // Ruta y navegación
    @Published var origin: Place?          // nil = mi ubicación
    @Published var destination: Place?
    @Published var routes: [RouteMode: RouteInfo] = [:]
    @Published var mode: RouteMode = .driving
    @Published var isNavigating = false
    @Published var isLoadingRoutes = false
    @Published var routeVersion = 0

    // Servicios
    private let placesService = PlacesService()
    private let routingService = RoutingService()
    private let geocodingService = GeocodingService()
    private var cityLocation: CLLocation?
    private var planToken = UUID()

    init() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.listsKey),
           let decoded = try? JSONDecoder().decode([String: [SavedPlace]].self, from: data) {
            lists = decoded
        } else if let data = defaults.data(forKey: Self.legacySavedKey),
                  let old = try? JSONDecoder().decode([SavedPlace].self, from: data) {
            lists = [PlaceList.saved.rawValue: old]   // migración de la versión anterior
        } else {
            lists = [:]
        }
        recents = defaults.stringArray(forKey: Self.recentsKey) ?? []
    }

    // MARK: Búsqueda

    func query(_ text: String, near center: CLLocationCoordinate2D) async -> [Place] {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return [] }
        let found = await placesService.search(t, near: center)
        googleMessage = placesService.lastGoogleMessage
        return found
    }

    func enrich(_ place: Place) async -> Place {
        let result = await placesService.details(for: place)
        googleMessage = placesService.lastGoogleMessage
        return result
    }

    func testGoogle(near center: CLLocationCoordinate2D) async {
        _ = await query("café", near: center)
    }

    func toggleCategory(_ category: PlaceCategory, near center: CLLocationCoordinate2D) async {
        if activeCategory == category {
            clearResults()
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

    func refreshCity(for location: CLLocation) async {
        if let last = cityLocation, last.distance(from: location) < 10_000 { return }
        cityLocation = location
        if let name = await geocodingService.cityName(for: location) {
            cityName = name
        }
    }

    // MARK: Pulsación larga en el mapa

    func dropPin(at coordinate: CLLocationCoordinate2D) async {
        let place = await geocodingService.place(at: coordinate)
        droppedPin = place
        selectedPlace = place
    }

    // MARK: Listas

    func items(in list: PlaceList) -> [SavedPlace] {
        lists[list.rawValue] ?? []
    }

    func contains(_ place: Place, in list: PlaceList) -> Bool {
        items(in: list).contains { $0.id == place.key }
    }

    func isSavedAnywhere(_ place: Place) -> Bool {
        PlaceList.allCases.contains { contains(place, in: $0) }
    }

    func toggle(_ place: Place, in list: PlaceList) {
        var current = items(in: list)
        if let index = current.firstIndex(where: { $0.id == place.key }) {
            current.remove(at: index)
        } else {
            current.insert(SavedPlace(place), at: 0)
        }
        lists[list.rawValue] = current
    }

    func remove(_ item: SavedPlace, from list: PlaceList) {
        var current = items(in: list)
        current.removeAll { $0.id == item.id }
        lists[list.rawValue] = current
    }

    // MARK: Rutas

    func startRoute(to place: Place, from userCoordinate: CLLocationCoordinate2D) async {
        tab = .explore
        selectedPlace = nil
        droppedPin = nil
        origin = nil
        destination = place
        await replan(userCoordinate: userCoordinate)
    }

    func setOrigin(_ place: Place?, userCoordinate: CLLocationCoordinate2D) async {
        origin = place
        await replan(userCoordinate: userCoordinate)
    }

    func setDestination(_ place: Place, userCoordinate: CLLocationCoordinate2D) async {
        destination = place
        await replan(userCoordinate: userCoordinate)
    }

    func swapEndpoints(userCoordinate: CLLocationCoordinate2D) async {
        guard let current = destination else { return }
        let oldOrigin = origin
        origin = current
        destination = oldOrigin ?? Place(name: "Mi ubicación", coordinate: userCoordinate)
        await replan(userCoordinate: userCoordinate)
    }

    func replan(userCoordinate: CLLocationCoordinate2D) async {
        guard let destination else { return }
        let token = UUID()
        planToken = token
        isNavigating = false
        routes = [:]
        isLoadingRoutes = true

        let start = origin?.coordinate ?? userCoordinate
        let result = await routingService.routes(from: start, to: destination)

        guard planToken == token else { return }   // cambió el plan mientras se calculaba
        routes = result
        if result[mode] == nil, let first = RouteMode.allCases.first(where: { result[$0] != nil }) {
            mode = first
        }
        isLoadingRoutes = false
        routeVersion += 1
    }

    /// Empieza el guiado desde tu posición actual.
    func beginNavigation(userCoordinate: CLLocationCoordinate2D) async {
        if origin != nil {
            origin = nil
            await replan(userCoordinate: userCoordinate)
        }
        guard routes[mode]?.route != nil else { return }
        isNavigating = true
    }

    /// Recalcula la ruta desde donde estás (te has salido del camino).
    func reroute(from coordinate: CLLocationCoordinate2D) async {
        guard let destination else { return }
        if let info = await routingService.route(from: coordinate, to: destination, mode: mode) {
            routes[mode] = info
        }
    }

    func stopRoute() {
        planToken = UUID()
        destination = nil
        origin = nil
        routes = [:]
        isNavigating = false
        isLoadingRoutes = false
    }
}
