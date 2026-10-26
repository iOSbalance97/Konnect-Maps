import MapKit
import CoreLocation

/// Cálculo de rutas con Apple Maps (coche, a pie y tiempo estimado en transporte).
struct RoutingService {
    func routes(from origin: CLLocationCoordinate2D, to place: Place) async -> [RouteMode: RouteInfo] {
        var result: [RouteMode: RouteInfo] = [:]
        for mode in RouteMode.allCases {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
            request.destination = place.mapItem
            request.transportType = mode.transportType
            let directions = MKDirections(request: request)
            if mode == .transit {
                if let eta = try? await directions.calculateETA() {
                    result[mode] = RouteInfo(time: eta.expectedTravelTime, distance: eta.distance, route: nil)
                }
            } else if let route = try? await directions.calculate().routes.first {
                result[mode] = RouteInfo(time: route.expectedTravelTime, distance: route.distance, route: route)
            }
        }
        return result
    }
}
