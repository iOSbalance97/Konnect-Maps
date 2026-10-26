import CoreLocation

/// Geocodificación inversa: coordenadas -> ciudad / dirección.
struct GeocodingService {
    func cityName(for location: CLLocation) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        return placemarks?.first?.locality
    }

    /// Dirección de un punto del mapa (pulsación larga).
    func place(at coordinate: CLLocationCoordinate2D) async -> Place {
        var place = Place(name: "Ubicación seleccionada", coordinate: coordinate)
        place.categoryText = "Dirección"
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let pm = (try? await CLGeocoder().reverseGeocodeLocation(location))?.first {
            let street = [pm.thoroughfare, pm.subThoroughfare].compactMap { $0 }.joined(separator: " ")
            if !street.isEmpty {
                place.name = street
            } else if let name = pm.name {
                place.name = name
            }
            let city = [pm.postalCode, pm.locality].compactMap { $0 }.joined(separator: " ")
            let parts = [street, city, pm.country ?? ""].filter { !$0.isEmpty }
            place.address = parts.joined(separator: ", ")
        }
        if place.address.isEmpty {
            place.address = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        }
        return place
    }
}
