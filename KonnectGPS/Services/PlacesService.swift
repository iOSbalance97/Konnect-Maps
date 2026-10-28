import SwiftUI
import MapKit
import CoreLocation
import UIKit

// MARK: - Configuración de Google

enum GoogleConfig {
    static let storageKey = "google_api_key"

    static var apiKey: String {
        (UserDefaults.standard.string(forKey: storageKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum GoogleError: Error {
    case http(Int)
    case decoding

    var message: String {
        switch self {
        case .http(let code):
            switch code {
            case 400: return "Petición no válida (400)"
            case 403: return "Clave rechazada o Places API (New) sin activar (403)"
            case 429: return "Límite de uso alcanzado (429)"
            default: return "Error de Google (\(code))"
            }
        case .decoding:
            return "Respuesta de Google no reconocida"
        }
    }
}

// MARK: - Respuestas de Google Places API (New)

private struct GPlacesResponse: Decodable { let places: [GPlace]? }
private struct GText: Decodable { let text: String? }
private struct GLatLng: Decodable { let latitude: Double; let longitude: Double }
private struct GHours: Decodable { let openNow: Bool?; let weekdayDescriptions: [String]? }
private struct GPhoto: Decodable { let name: String? }
private struct GAuthor: Decodable { let displayName: String? }
private struct GReview: Decodable {
    let rating: Double?
    let relativePublishTimeDescription: String?
    let text: GText?
    let authorAttribution: GAuthor?
}
private struct GPlace: Decodable {
    let id: String?
    let displayName: GText?
    let formattedAddress: String?
    let location: GLatLng?
    let rating: Double?
    let userRatingCount: Int?
    let nationalPhoneNumber: String?
    let websiteUri: String?
    let primaryTypeDisplayName: GText?
    let currentOpeningHours: GHours?
    let regularOpeningHours: GHours?
    let photos: [GPhoto]?
    let reviews: [GReview]?

    func toPlace() -> Place? {
        guard let loc = location, let name = displayName?.text else { return nil }
        var p = Place(name: name, coordinate: CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude))
        p.address = formattedAddress ?? ""
        p.phone = nationalPhoneNumber
        p.website = websiteUri.flatMap { URL(string: $0) }
        p.categoryText = primaryTypeDisplayName?.text ?? "Lugar"
        p.rating = rating
        p.ratingCount = userRatingCount
        p.openNow = currentOpeningHours?.openNow
        p.weekdayHours = (currentOpeningHours ?? regularOpeningHours)?.weekdayDescriptions ?? []
        p.photoNames = Array((photos ?? []).compactMap { $0.name }.prefix(6))
        p.googleID = id
        return p
    }
}

// MARK: - Proveedor de Google

struct GooglePlacesProvider {
    let apiKey: String

    private static let searchMask = [
        "places.id", "places.displayName", "places.formattedAddress", "places.location",
        "places.rating", "places.userRatingCount", "places.nationalPhoneNumber",
        "places.websiteUri", "places.primaryTypeDisplayName",
        "places.currentOpeningHours", "places.regularOpeningHours", "places.photos"
    ].joined(separator: ",")

    private func makeRequest(url: URL, method: String, mask: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        req.setValue(mask, forHTTPHeaderField: "X-Goog-FieldMask")
        if let bundle = Bundle.main.bundleIdentifier {
            req.setValue(bundle, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        return req
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw GoogleError.http(code) }
        return data
    }

    func search(_ text: String, near center: CLLocationCoordinate2D,
                radius: Double = 5000, maxResults: Int = 20) async throws -> [Place] {
        guard let url = URL(string: "https://places.googleapis.com/v1/places:searchText") else { return [] }
        var req = makeRequest(url: url, method: "POST", mask: Self.searchMask)
        let centerJSON: [String: Any] = ["latitude": center.latitude, "longitude": center.longitude]
        let circleJSON: [String: Any] = ["center": centerJSON, "radius": radius]
        let biasJSON: [String: Any] = ["circle": circleJSON]
        let body: [String: Any] = [
            "textQuery": text,
            "languageCode": "es",
            "maxResultCount": maxResults,
            "locationBias": biasJSON
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data = try await send(req)
        guard let decoded = try? JSONDecoder().decode(GPlacesResponse.self, from: data) else {
            throw GoogleError.decoding
        }
        return (decoded.places ?? []).compactMap { $0.toPlace() }
    }

    func reviews(for id: String) async throws -> [PlaceReview] {
        var comps = URLComponents(string: "https://places.googleapis.com/v1/places/\(id)")
        comps?.queryItems = [URLQueryItem(name: "languageCode", value: "es")]
        guard let url = comps?.url else { return [] }
        let data = try await send(makeRequest(url: url, method: "GET", mask: "reviews"))
        guard let place = try? JSONDecoder().decode(GPlace.self, from: data) else {
            throw GoogleError.decoding
        }
        return (place.reviews ?? []).prefix(5).map { r in
            PlaceReview(author: r.authorAttribution?.displayName ?? "Usuario",
                        rating: r.rating ?? 0,
                        text: r.text?.text ?? "",
                        time: r.relativePublishTimeDescription ?? "")
        }
    }
}

// MARK: - Proveedor de Apple

struct AppleMapsProvider {
    func search(_ text: String, near center: CLLocationCoordinate2D, radius: Double = 5000) async -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = MKCoordinateRegion(center: center,
                                            latitudinalMeters: radius * 2,
                                            longitudinalMeters: radius * 2)
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        return response.mapItems.map { Place(appleItem: $0) }
    }
}

// MARK: - Servicio principal

/// Usa Google Places si hay clave configurada; si no (o si falla), Apple Maps.
@MainActor
final class PlacesService {
    private(set) var lastGoogleMessage: String?

    func search(_ text: String, near center: CLLocationCoordinate2D) async -> [Place] {
        let key = GoogleConfig.apiKey
        if !key.isEmpty {
            do {
                let found = try await GooglePlacesProvider(apiKey: key).search(text, near: center)
                lastGoogleMessage = "Conectado a Google Maps"
                if !found.isEmpty { return found }
            } catch let error as GoogleError {
                lastGoogleMessage = error.message
            } catch {
                lastGoogleMessage = error.localizedDescription
            }
        } else {
            lastGoogleMessage = nil
        }
        return await AppleMapsProvider().search(text, near: center)
    }

    /// Completa un lugar con valoración, horarios, fotos y reseñas de Google.
    func details(for place: Place) async -> Place {
        let key = GoogleConfig.apiKey
        guard !key.isEmpty, place.categoryText != "Dirección", place.categoryText != "Mi coche" else { return place }
        let google = GooglePlacesProvider(apiKey: key)
        var result = place
        do {
            if result.googleID == nil {
                let candidates = try await google.search(place.name, near: place.coordinate, radius: 150, maxResults: 3)
                guard let match = candidates.first(where: { metersBetween($0.coordinate, place.coordinate) < 200 }) else {
                    return place
                }
                result = result.merged(with: match)
            }
            if let id = result.googleID, result.reviews.isEmpty {
                result.reviews = try await google.reviews(for: id)
            }
            lastGoogleMessage = "Conectado a Google Maps"
        } catch let error as GoogleError {
            lastGoogleMessage = error.message
        } catch {
            lastGoogleMessage = error.localizedDescription
        }
        return result
    }
}

// MARK: - Fotos de Google

enum PhotoLoader {
    static func load(name: String, maxWidth: Int) async -> UIImage? {
        let key = GoogleConfig.apiKey
        guard !key.isEmpty, var comps = URLComponents(string: "https://places.googleapis.com/v1/\(name)/media") else {
            return nil
        }
        comps.queryItems = [
            URLQueryItem(name: "maxWidthPx", value: "\(maxWidth)"),
            URLQueryItem(name: "key", value: key)
        ]
        guard let url = comps.url else { return nil }
        var req = URLRequest(url: url)
        if let bundle = Bundle.main.bundleIdentifier {
            req.setValue(bundle, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return UIImage(data: data)
    }
}

struct GooglePhotoView: View {
    let photoName: String
    var maxWidth: Int = 800
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .overlay(ProgressView())
            }
        }
        .task(id: photoName) {
            image = await PhotoLoader.load(name: photoName, maxWidth: maxWidth)
        }
    }
}
