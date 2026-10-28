import CarPlay
import MapKit
import SwiftUI
import UIKit

/// Escena de CarPlay para Konnect GPS (app de navegación).
/// NO está en la compilación actual: requiere cuenta de pago de Apple Developer y el
/// permiso "CarPlay Maps" concedido por Apple. Ver CarPlay/LEEME.md para activarla.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate, CPMapTemplateDelegate {
    private var interfaceController: CPInterfaceController?
    private var carWindow: CPWindow?
    private var mapTemplate: CPMapTemplate?

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController,
                                  to window: CPWindow) {
        self.interfaceController = interfaceController
        self.carWindow = window
        window.rootViewController = UIHostingController(rootView: CarMapView())

        let template = CPMapTemplate()
        template.mapDelegate = self
        template.leadingNavigationBarButtons = [
            CPBarButton(title: "Lugares") { [weak self] _ in self?.showPlaces() }
        ]
        mapTemplate = template
        interfaceController.setRootTemplate(template, animated: true, completion: nil)
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController,
                                  from window: CPWindow) {
        self.interfaceController = nil
        self.carWindow = nil
        self.mapTemplate = nil
    }

    // MARK: Lista de lugares (Favoritos, Guardados, Relevantes, Recientes)

    private func showPlaces() {
        var sections: [CPListSection] = []
        for list in PlaceList.allCases {
            let items = savedItems(for: list)
            if !items.isEmpty {
                sections.append(CPListSection(items: items, header: list.title, sectionIndexTitle: nil))
            }
        }
        let template = CPListTemplate(title: "Lugares", sections: sections)
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    private func savedItems(for list: PlaceList) -> [CPListItem] {
        let stored = UserDefaults.standard.data(forKey: "place_lists_v2")
        let decoded = stored.flatMap { try? JSONDecoder().decode([String: [SavedPlace]].self, from: $0) } ?? [:]
        return (decoded[list.rawValue] ?? []).map { saved in
            let item = CPListItem(text: saved.name, detailText: saved.address)
            item.handler = { [weak self] _, completion in
                self?.preview(saved.place)
                completion()
            }
            return item
        }
    }

    // MARK: Vista previa de la ruta

    private func preview(_ place: Place) {
        guard let mapTemplate else { return }
        interfaceController?.popToRootTemplate(animated: true, completion: nil)
        let choice = CPRouteChoice(summaryVariants: [place.name],
                                   additionalInformationVariants: [place.address],
                                   selectionSummaryVariants: [place.name])
        let trip = CPTrip(origin: MKMapItem.forCurrentLocation(),
                          destination: place.mapItem,
                          routeChoices: [choice])
        mapTemplate.showTripPreviews([trip], textConfiguration: nil)
    }

    func mapTemplate(_ mapTemplate: CPMapTemplate, startedTrip trip: CPTrip, using routeChoice: CPRouteChoice) {
        mapTemplate.hideTripPreviews()
        // La ruta real y las indicaciones las gestiona la app; aquí se abre el guiado.
        NotificationCenter.default.post(name: .konnectCarPlayStartTrip, object: trip.destination)
    }
}

extension Notification.Name {
    static let konnectCarPlayStartTrip = Notification.Name("konnectCarPlayStartTrip")
}

/// Mapa que se dibuja en la pantalla del coche.
struct CarMapView: View {
    var body: some View {
        Map(initialPosition: .userLocation(fallback: .automatic)) {
            UserAnnotation()
        }
        .mapStyle(.standard(emphasis: .muted))
    }
}
