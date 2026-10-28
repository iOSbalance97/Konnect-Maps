import SwiftUI
import CoreLocation

struct Radar: Identifiable {
    let id: Int64
    let latitude: Double
    let longitude: Double
    let maxSpeed: Int?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct OverpassResponse: Decodable {
    struct Element: Decodable {
        let id: Int64
        let lat: Double?
        let lon: Double?
        let tags: [String: String]?
    }
    let elements: [Element]
}

/// Radares (cámaras de velocidad) desde OpenStreetMap (Overpass API).
@MainActor
final class RadarService: ObservableObject {
    private static let showKey = "show_radars"

    @Published var showRadars: Bool {
        didSet { UserDefaults.standard.set(showRadars, forKey: Self.showKey) }
    }
    @Published private(set) var radars: [Radar] = []
    @Published private(set) var status: String?

    private var known: [Int64: Radar] = [:]
    private var loadedTiles = Set<String>()
    private var lastNavFetch: CLLocation?
    private var isFetching = false

    init() {
        showRadars = UserDefaults.standard.bool(forKey: Self.showKey)
    }

    /// Radares cercanos a un punto (para dibujar solo los que importan).
    func visible(near center: CLLocationCoordinate2D, within meters: Double = 15000) -> [Radar] {
        radars.filter { metersBetween($0.coordinate, center) < meters }
    }

    func refresh(around center: CLLocationCoordinate2D, radius: Double = 6000) async {
        let tiles = Self.tiles(around: center, radius: radius)
        let missing = tiles.filter { !loadedTiles.contains($0) }
        guard !missing.isEmpty, !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        let dLat = radius / 111_000
        let dLon = radius / (111_000 * max(cos(center.latitude * .pi / 180), 0.2))
        let found = await Self.fetch(south: center.latitude - dLat, west: center.longitude - dLon,
                                     north: center.latitude + dLat, east: center.longitude + dLon)
        if let found {
            for radar in found { known[radar.id] = radar }
            loadedTiles.formUnion(tiles)
            radars = Array(known.values)
            status = nil
        } else {
            status = "No se pudieron cargar los radares"
        }
    }

    /// Durante la navegación: recarga cuando te mueves más de 2 km.
    func refreshIfNeeded(near location: CLLocation) async {
        if let last = lastNavFetch, last.distance(from: location) < 2000 { return }
        lastNavFetch = location
        await refresh(around: location.coordinate, radius: 7000)
    }

    // MARK: Red

    private static func tiles(around c: CLLocationCoordinate2D, radius: Double) -> [String] {
        let dLat = radius / 111_000
        let dLon = radius / (111_000 * max(cos(c.latitude * .pi / 180), 0.2))
        let step = 0.05
        var result: [String] = []
        var lat = floor((c.latitude - dLat) / step)
        let latEnd = floor((c.latitude + dLat) / step)
        let lonStart = floor((c.longitude - dLon) / step)
        let lonEnd = floor((c.longitude + dLon) / step)
        while lat <= latEnd {
            var lon = lonStart
            while lon <= lonEnd {
                result.append("\(Int(lat)),\(Int(lon))")
                lon += 1
            }
            lat += 1
        }
        return result
    }

    private static func fetch(south: Double, west: Double, north: Double, east: Double) async -> [Radar]? {
        let query = String(format: "[out:json][timeout:20];node[\"highway\"=\"speed_camera\"](%.5f,%.5f,%.5f,%.5f);out body;",
                           south, west, north, east)
        var comps = URLComponents(string: "https://overpass-api.de/api/interpreter")
        comps?.queryItems = [URLQueryItem(name: "data", value: query)]
        guard let url = comps?.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("KonnectGPS/0.4 (iOS)", forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let decoded = try? JSONDecoder().decode(OverpassResponse.self, from: data) else {
            return nil
        }
        return decoded.elements.compactMap { element in
            guard let lat = element.lat, let lon = element.lon else { return nil }
            var limit: Int?
            if let raw = element.tags?["maxspeed"] {
                let digits = String(raw.prefix(while: { $0.isNumber }))
                limit = Int(digits)
            }
            return Radar(id: element.id, latitude: lat, longitude: lon, maxSpeed: limit)
        }
    }
}
