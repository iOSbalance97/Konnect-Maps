import SwiftUI
import MapKit
import CoreLocation

// MARK: - Utilidades

extension CLLocationCoordinate2D {
    static var madrid: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038)
    }
}

extension MKCoordinateRegion {
    static var madrid: MKCoordinateRegion {
        MKCoordinateRegion(center: .madrid, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
    }
}

extension Double {
    /// Metros -> "350 m" / "3,2 km"
    var distanceText: String {
        if self < 1000 { return "\(Int(self.rounded())) m" }
        return "\((self / 1000).formatted(.number.precision(.fractionLength(1)))) km"
    }

    var ratingText: String {
        self.formatted(.number.precision(.fractionLength(1)))
    }

    /// Segundos -> "12 min" / "1 h 5 min"
    var durationText: String {
        let minutes = Int((self / 60).rounded())
        if minutes >= 60 { return "\(minutes / 60) h \(minutes % 60) min" }
        return "\(max(minutes, 1)) min"
    }
}

/// Icono del giro según el texto de la instrucción.
func maneuverSymbol(for instruction: String) -> String {
    let t = instruction.lowercased()
    if t.contains("cambio de sentido") || t.contains("da la vuelta") || t.contains("u-turn") { return "arrow.uturn.left" }
    if t.contains("rotonda") || t.contains("roundabout") { return "arrow.triangle.2.circlepath" }
    if t.contains("derecha") || t.contains("right") { return "arrow.turn.up.right" }
    if t.contains("izquierda") || t.contains("left") { return "arrow.turn.up.left" }
    if t.contains("destino") || t.contains("destination") { return "flag.checkered" }
    return "arrow.up"
}

func metersBetween(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
    CLLocation(latitude: a.latitude, longitude: a.longitude)
        .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
}

// MARK: - Categorías

enum PlaceCategory: String, CaseIterable, Identifiable {
    case restaurants, cafes, gas, shopping
    var id: String { rawValue }

    var title: String {
        switch self {
        case .restaurants: return "Restaurantes"
        case .cafes: return "Cafeterías"
        case .gas: return "Gasolineras"
        case .shopping: return "Compras"
        }
    }
    var icon: String {
        switch self {
        case .restaurants: return "fork.knife"
        case .cafes: return "cup.and.saucer.fill"
        case .gas: return "fuelpump.fill"
        case .shopping: return "cart.fill"
        }
    }
    var color: Color {
        switch self {
        case .restaurants: return .orange
        case .cafes: return .purple
        case .gas: return Color.konnectBlue
        case .shopping: return .green
        }
    }
    var query: String {
        switch self {
        case .restaurants: return "restaurantes"
        case .cafes: return "cafeterías"
        case .gas: return "gasolineras"
        case .shopping: return "tiendas"
        }
    }
}

// MARK: - Lugar

struct PlaceReview: Identifiable {
    let id = UUID()
    var author: String
    var rating: Double
    var text: String
    var time: String
}

struct Place: Identifiable {
    let id = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D
    var address: String = ""
    var phone: String? = nil
    var website: URL? = nil
    var categoryText: String = "Lugar"
    var rating: Double? = nil
    var ratingCount: Int? = nil
    var openNow: Bool? = nil
    var weekdayHours: [String] = []
    var photoNames: [String] = []
    var reviews: [PlaceReview] = []
    var googleID: String? = nil

    var hasGoogleData: Bool { googleID != nil }
    var key: String { String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude) }

    /// Elemento de Apple Maps, necesario para calcular rutas y abrir Apple Maps.
    var mapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        return item
    }

    func distance(from location: CLLocation?) -> String? {
        guard let location else { return nil }
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: here).distanceText
    }

    var shareURL: URL {
        var c = URLComponents(string: "https://maps.apple.com/")!
        c.queryItems = [
            URLQueryItem(name: "ll", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "q", value: name)
        ]
        return c.url ?? URL(string: "https://maps.apple.com/")!
    }

    /// Combina un lugar de Apple con los datos de Google (valoración, horarios, fotos...).
    func merged(with google: Place) -> Place {
        var r = self
        r.googleID = google.googleID
        r.rating = google.rating
        r.ratingCount = google.ratingCount
        r.openNow = google.openNow
        if !google.weekdayHours.isEmpty { r.weekdayHours = google.weekdayHours }
        if !google.photoNames.isEmpty { r.photoNames = google.photoNames }
        if r.phone == nil { r.phone = google.phone }
        if r.website == nil { r.website = google.website }
        if r.address.isEmpty { r.address = google.address }
        if r.categoryText == "Lugar" { r.categoryText = google.categoryText }
        return r
    }
}

extension Place {
    init(appleItem item: MKMapItem) {
        self.init(name: item.name ?? "Lugar", coordinate: item.placemark.coordinate)
        address = item.placemark.title ?? ""
        phone = item.phoneNumber
        website = item.url
        categoryText = Place.categoryName(for: item.pointOfInterestCategory)
    }

    static func categoryName(for category: MKPointOfInterestCategory?) -> String {
        guard let c = category else { return "Lugar" }
        let names: [MKPointOfInterestCategory: String] = [
            .restaurant: "Restaurante", .cafe: "Cafetería", .gasStation: "Gasolinera",
            .museum: "Museo", .park: "Parque", .store: "Tienda", .hotel: "Hotel",
            .pharmacy: "Farmacia", .parking: "Aparcamiento", .bakery: "Panadería",
            .nightlife: "Ocio nocturno", .theater: "Teatro", .hospital: "Hospital",
            .school: "Colegio", .university: "Universidad"
        ]
        return names[c] ?? "Lugar"
    }
}

// MARK: - Guardados

struct SavedPlace: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

    init(_ place: Place) {
        id = place.key
        name = place.name
        address = place.address
        latitude = place.coordinate.latitude
        longitude = place.coordinate.longitude
    }

    var place: Place {
        Place(name: name,
              coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
              address: address)
    }
}

// MARK: - Rutas

enum RouteMode: String, CaseIterable, Identifiable {
    case driving, transit, walking
    var id: String { rawValue }

    var title: String {
        switch self {
        case .driving: return "Coche"
        case .transit: return "Transporte"
        case .walking: return "A pie"
        }
    }
    var icon: String {
        switch self {
        case .driving: return "car.fill"
        case .transit: return "bus.fill"
        case .walking: return "figure.walk"
        }
    }
    var transportType: MKDirectionsTransportType {
        switch self {
        case .driving: return .automobile
        case .transit: return .transit
        case .walking: return .walking
        }
    }
}

struct RouteInfo {
    let time: TimeInterval
    let distance: CLLocationDistance
    let route: MKRoute?   // nil en transporte público (solo hay tiempo estimado)

    var timeText: String { time.durationText }
    var arrivalText: String {
        Date().addingTimeInterval(time).formatted(date: .omitted, time: .shortened)
    }
}


// MARK: - Listas de lugares

enum PlaceList: String, CaseIterable, Identifiable {
    case favorites, saved, relevant
    var id: String { rawValue }

    var title: String {
        switch self {
        case .favorites: return "Favoritos"
        case .saved: return "Guardados"
        case .relevant: return "Sitios relevantes"
        }
    }
    var icon: String {
        switch self {
        case .favorites: return "heart.fill"
        case .saved: return "bookmark.fill"
        case .relevant: return "star.fill"
        }
    }
    var color: Color {
        switch self {
        case .favorites: return .pink
        case .saved: return Color.konnectBlue
        case .relevant: return .yellow
        }
    }
}


// MARK: - Pines de listas en el mapa

struct SavedPin: Identifiable {
    let id: String
    let list: PlaceList
    let item: SavedPlace
}

// MARK: - Coche aparcado

struct ParkedCar: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var date: Date
    var reason: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Lugar para mostrar la ficha del coche.
    var place: Place {
        var p = Place(name: "Coche aparcado", coordinate: coordinate)
        p.categoryText = "Mi coche"
        p.address = "\(reason) · \(date.formatted(date: .abbreviated, time: .shortened))"
        return p
    }
}

// MARK: - Peligros en la ruta (radares y avisos)

struct Hazard {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String
    let icon: String
    let color: Color
    let limit: Int?
}

struct NearbyHazard {
    let hazard: Hazard
    let distance: CLLocationDistance
}
