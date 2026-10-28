import SwiftUI
import MapKit
import CoreLocation
import AVFoundation

/// Guiado paso a paso: giro siguiente, distancia restante, voz y detección de desvío.
@MainActor
final class NavigationEngine: ObservableObject {
    @Published private(set) var distanceToManeuver: CLLocationDistance = 0
    @Published private(set) var maneuverText = ""
    @Published private(set) var maneuverIcon = "arrow.up"
    @Published private(set) var remainingDistance: CLLocationDistance = 0
    @Published private(set) var remainingTime: TimeInterval = 0
    @Published private(set) var hasArrived = false
    @Published private(set) var needsReroute = false
    @Published private(set) var upcomingStepIndex: Int?
    @Published private(set) var nearbyHazard: NearbyHazard?
    @Published var isMuted = false {
        didSet { if isMuted { synthesizer.stopSpeaking(at: .immediate) } }
    }

    private var route: MKRoute?
    private var stepIndex = 0
    private var spoken = Set<String>()
    private var offRouteCount = 0
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: Ciclo de vida

    func start(route: MKRoute) {
        self.route = route
        stepIndex = 0
        spoken = []
        offRouteCount = 0
        needsReroute = false
        hasArrived = false
        nearbyHazard = nil
        upcomingStepIndex = route.steps.firstIndex(where: { !$0.instructions.isEmpty })
        remainingDistance = route.distance
        remainingTime = route.expectedTravelTime
        if let first = route.steps.first(where: { !$0.instructions.isEmpty }) {
            maneuverText = first.instructions
            maneuverIcon = maneuverSymbol(for: first.instructions)
            distanceToManeuver = first.distance
        }
    }

    func stop() {
        route = nil
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func resetOffRoute() {
        offRouteCount = 0
        needsReroute = false
    }

    // MARK: Actualización con la posición

    func update(with location: CLLocation) {
        guard let route, !hasArrived else { return }
        let steps = route.steps
        guard !steps.isEmpty else { return }

        // 1) ¿Te has salido de la ruta?
        if location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 80 {
            let off = Self.distance(from: location.coordinate, to: route.polyline)
            offRouteCount = off > 60 ? offRouteCount + 1 : 0
            if offRouteCount >= 3 {
                needsReroute = true
                return
            }
        }

        // 2) ¿Has llegado?
        if let last = steps.last, location.distance(from: Self.endLocation(of: last)) < 30 {
            hasArrived = true
            remainingDistance = 0
            remainingTime = 0
            maneuverText = "Has llegado a tu destino"
            maneuverIcon = "flag.checkered"
            distanceToManeuver = 0
            speak("Has llegado a tu destino")
            return
        }

        // 3) Avanzar el paso actual (solo hacia delante)
        while stepIndex < steps.count - 1 {
            let next = steps[stepIndex + 1]
            let dCurrent = location.distance(from: Self.endLocation(of: steps[stepIndex]))
            let dNext = location.distance(from: Self.endLocation(of: next))
            if dCurrent < 35 || dNext < next.distance - 15 {
                stepIndex += 1
            } else {
                break
            }
        }

        let toEnd = location.distance(from: Self.endLocation(of: steps[stepIndex]))
        let upcomingIndex = steps.indices.dropFirst(stepIndex + 1).first(where: { !steps[$0].instructions.isEmpty })
        upcomingStepIndex = upcomingIndex
        let upcoming = upcomingIndex.map { steps[$0] }

        if let upcoming {
            maneuverText = upcoming.instructions
            maneuverIcon = maneuverSymbol(for: upcoming.instructions)
            distanceToManeuver = toEnd
            announce(text: upcoming.instructions, distance: toEnd)
        } else {
            maneuverText = "Llegarás a tu destino"
            maneuverIcon = "flag.checkered"
            distanceToManeuver = toEnd
        }

        let after = steps.dropFirst(stepIndex + 1).reduce(0) { $0 + $1.distance }
        remainingDistance = toEnd + after
        remainingTime = route.expectedTravelTime * remainingDistance / max(route.distance, 1)
    }

    // MARK: Peligros (radares y avisos de conductores)

    func checkHazards(_ hazards: [Hazard], at location: CLLocation) {
        var best: (hazard: Hazard, distance: CLLocationDistance)?
        for hazard in hazards {
            let d = location.distance(from: CLLocation(latitude: hazard.coordinate.latitude,
                                                       longitude: hazard.coordinate.longitude))
            guard d < 500 else { continue }
            // Solo los que quedan por delante (si se conoce el rumbo).
            if location.course >= 0 && location.speed > 2 {
                let bearing = Self.bearing(from: location.coordinate, to: hazard.coordinate)
                var diff = abs(bearing - location.course).truncatingRemainder(dividingBy: 360)
                if diff > 180 { diff = 360 - diff }
                guard diff < 70 else { continue }
            }
            if best == nil || d < best!.distance { best = (hazard, d) }
        }
        if let best {
            nearbyHazard = NearbyHazard(hazard: best.hazard, distance: best.distance)
            let key = "hz-\(best.hazard.id)"
            if best.distance < 450 && !spoken.contains(key) {
                spoken.insert(key)
                let rounded = max(Int((best.distance / 50).rounded()) * 50, 50)
                speak("\(best.hazard.title) en \(rounded) metros")
            }
        } else {
            nearbyHazard = nil
        }
    }

    private static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: Voz

    private func announce(text: String, distance: CLLocationDistance) {
        let farKey = "\(stepIndex)-far"
        let nearKey = "\(stepIndex)-near"
        if distance <= 80 {
            if !spoken.contains(nearKey) {
                spoken.insert(nearKey)
                spoken.insert(farKey)
                speak(text)
            }
        } else if distance <= 450 {
            if !spoken.contains(farKey) {
                spoken.insert(farKey)
                let rounded = max(Int((distance / 50).rounded()) * 50, 100)
                speak("En \(rounded) metros, \(text)")
            }
        }
    }

    private func speak(_ text: String) {
        guard !isMuted else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.preferredLanguages.first ?? "es-ES")
        synthesizer.speak(utterance)
    }

    // MARK: Geometría

    private static func endLocation(of step: MKRoute.Step) -> CLLocation {
        let poly = step.polyline
        let count = poly.pointCount
        guard count > 0 else { return CLLocation(latitude: 0, longitude: 0) }
        let coordinate = poly.points()[count - 1].coordinate
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// Distancia mínima (en metros) de un punto a la polilínea de la ruta.
    private static func distance(from coordinate: CLLocationCoordinate2D, to polyline: MKPolyline) -> CLLocationDistance {
        let count = polyline.pointCount
        guard count > 1 else { return .greatestFiniteMagnitude }
        let p = MKMapPoint(coordinate)
        let pts = polyline.points()
        var best = CLLocationDistance.greatestFiniteMagnitude
        for i in 0..<(count - 1) {
            let a = pts[i]
            let b = pts[i + 1]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let len2 = dx * dx + dy * dy
            var t = len2 == 0 ? 0 : ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2
            t = max(0, min(1, t))
            let projected = MKMapPoint(x: a.x + t * dx, y: a.y + t * dy)
            best = min(best, p.distance(to: projected))
        }
        return best
    }
}
