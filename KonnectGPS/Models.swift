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

extension Color {
    static let konnectBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let panel = Color(red: 0.07, green: 0.10, blue: 0.17)
}

extension Double {
    /// Metros -> "350 m" / "3,2 km"
    var distanceText: String {
        if self < 1000 { return "\(Int(self.rounded())) m" }
        return "\((self / 1000).formatted(.number.precision(.fractionLength(1)))) km"
    }
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

struct Place: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    var addressOverride: String? = nil

    var name: String { mapItem.name ?? "Lugar" }
    var coordinate: CLLocationCoordinate2D { mapItem.placemark.coordinate }
    var address: String { addressOverride ?? mapItem.placemark.title ?? "" }
    var phone: String? { mapItem.phoneNumber }
    var website: URL? { mapItem.url }
    var key: String { String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude) }

    var categoryText: String {
        guard let c = mapItem.pointOfInterestCategory else { return "Lugar" }
        let names: [MKPointOfInterestCategory: String] = [
            .restaurant: "Restaurante", .cafe: "Cafetería", .gasStation: "Gasolinera",
            .museum: "Museo", .park: "Parque", .store: "Tienda", .hotel: "Hotel",
            .pharmacy: "Farmacia", .parking: "Aparcamiento", .bakery: "Panadería",
            .nightlife: "Ocio nocturno", .theater: "Teatro", .hospital: "Hospital",
            .school: "Colegio", .university: "Universidad"
        ]
        return names[c] ?? "Lugar"
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
        let item = MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)))
        item.name = name
        return Place(mapItem: item, addressOverride: address)
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

    var timeText: String {
        let minutes = Int((time / 60).rounded())
        if minutes >= 60 { return "\(minutes / 60) h \(minutes % 60) min" }
        return "\(max(minutes, 1)) min"
    }
    var arrivalText: String {
        Date().addingTimeInterval(time).formatted(date: .omitted, time: .shortened)
    }
}
