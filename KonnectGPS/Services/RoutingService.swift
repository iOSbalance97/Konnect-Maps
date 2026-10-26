import MapKit
import CoreLocation

/// Cálculo de rutas con Apple Maps (coche, a pie y tiempo estimado en transporte).
struct RoutingService {
    func route(from origin: CLLocationCoordinate2D, to place: Place, mode: RouteMode) async -> RouteInfo? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = place.mapItem
        request.transportType = mode.transportType
        let directions = MKDirections(request: request)
        if mode == .transit {
            if let eta = try? await directions.calculateETA() {
                return RouteInfo(time: eta.expectedTravelTime, distance: eta.distance, route: nil)
            }
            return nil
        }
        if let route = try? await directions.calculate().routes.first {
            return RouteInfo(time: route.expectedTravelTime, distance: route.distance, route: route)
        }
        return nil
    }

    func routes(from origin: CLLocationCoordinate2D, to place: Place) async -> [RouteMode: RouteInfo] {
        var result: [RouteMode: RouteInfo] = [:]
        for mode in RouteMode.allCases {
            if let info = await route(from: origin, to: place, mode: mode) {
                result[mode] = info
            }
        }
        return result
    }
}
