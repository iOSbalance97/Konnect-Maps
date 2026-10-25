import SwiftUI
import MapKit

struct PlaceDetailView: View {
    let place: Place
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name).font(.title.bold())
                    HStack(spacing: 6) {
                        Text(place.categoryText)
                        if let d = place.distance(from: location.location) { Text("· \(d)") }
                    }
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        Task { await model.startRoute(to: place, from: location.location?.coordinate ?? .madrid) }
                    } label: {
                        ActionLabel(title: "Cómo llegar", icon: "car.fill", prominent: true)
                    }
                    .buttonStyle(.plain)

                    Button { model.toggleSaved(place) } label: {
                        ActionLabel(title: model.isSaved(place) ? "Guardado" : "Guardar",
                                    icon: model.isSaved(place) ? "bookmark.fill" : "bookmark")
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: place.shareURL) {
                        ActionLabel(title: "Compartir", icon: "square.and.arrow.up")
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                if !place.address.isEmpty {
                    InfoRow(icon: "mappin.and.ellipse", text: place.address)
                }
                if let phone = place.phone {
                    let digits = phone.filter { $0.isNumber || $0 == "+" }
                    if let url = URL(string: "tel:\(digits)") {
                        Link(destination: url) { InfoRow(icon: "phone.fill", text: phone) }
                    }
                }
                if let web = place.website {
                    Link(destination: web) { InfoRow(icon: "link", text: web.host ?? web.absoluteString) }
                }

                Button {
                    place.mapItem.openInMaps()
                } label: {
                    Label("Abrir en Apple Maps", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.panel)
    }
}

struct ActionLabel: View {
    let title: String
    let icon: String
    var prominent = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.footnote.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(.white)
        .background(prominent ? Color.konnectBlue : Color.white.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.konnectBlue)
                .frame(width: 24)
            Text(text)
                .multilineTextAlignment(.leading)
                .foregroundStyle(.primary)
            Spacer()
        }
    }
}
