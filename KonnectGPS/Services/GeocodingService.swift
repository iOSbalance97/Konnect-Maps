import CoreLocation

/// Convierte coordenadas en nombre de ciudad.
struct GeocodingService {
    func cityName(for location: CLLocation) async -> String? {
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location)
        return placemarks?.first?.locality
    }
}
