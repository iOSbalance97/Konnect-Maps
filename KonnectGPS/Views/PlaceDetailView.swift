import SwiftUI
import MapKit

struct PlaceDetailView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @State private var detail: Place
    @State private var showHours = false

    init(place: Place) {
        _detail = State(initialValue: place)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero

                VStack(alignment: .leading, spacing: 6) {
                    Text(detail.name).font(.title.bold())
                    HStack(spacing: 6) {
                        Text(detail.categoryText)
                        if let d = detail.distance(from: location.location) { Text("· \(d)") }
                    }
                    .foregroundStyle(.secondary)
                    ratingRow
                }

                actions

                Divider()

                if !detail.address.isEmpty {
                    InfoRow(icon: "mappin.and.ellipse", text: detail.address)
                }
                if let phone = detail.phone {
                    let digits = phone.filter { $0.isNumber || $0 == "+" }
                    if let url = URL(string: "tel:\(digits)") {
                        Link(destination: url) { InfoRow(icon: "phone.fill", text: phone) }
                    }
                }
                if let web = detail.website {
                    Link(destination: web) { InfoRow(icon: "link", text: web.host ?? web.absoluteString) }
                }
                if !detail.weekdayHours.isEmpty { hours }
                if !detail.reviews.isEmpty { reviews }

                Button {
                    detail.mapItem.openInMaps()
                } label: {
                    Label("Abrir en Apple Maps", systemImage: "map")
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .foregroundStyle(Color.white)
                        .liquidGlass(in: Capsule(), interactive: true)
                }
                .buttonStyle(.plain)

                if detail.hasGoogleData {
                    Text("Valoraciones, horarios y fotos: Google Maps")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .darkSheetBackground()
        .task {
            detail = await model.enrich(detail)
        }
    }

    // MARK: Secciones

    @ViewBuilder
    private var hero: some View {
        if !detail.photoNames.isEmpty {
            TabView {
                ForEach(detail.photoNames, id: \.self) { name in
                    GooglePhotoView(photoName: name)
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .clipped()
                }
            }
            .tabViewStyle(.page)
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    @ViewBuilder
    private var ratingRow: some View {
        if let rating = detail.rating {
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(Color.yellow)
                Text(rating.ratingText).fontWeight(.semibold)
                if let count = detail.ratingCount {
                    Text("(\(count.formatted()))").foregroundStyle(.secondary)
                }
                if let open = detail.openNow {
                    Text(open ? "· Abierto ahora" : "· Cerrado ahora")
                        .foregroundStyle(open ? Color.green : Color.red)
                }
            }
            .font(.subheadline)
        }
    }

    private var actions: some View {
        GlassGroup(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    Task { await model.startRoute(to: detail, from: location.location?.coordinate ?? .madrid) }
                } label: {
                    ActionLabel(title: "Cómo llegar", icon: "car.fill", prominent: true)
                }
                .buttonStyle(.plain)

                Button { model.toggleSaved(detail) } label: {
                    ActionLabel(title: model.isSaved(detail) ? "Guardado" : "Guardar",
                                icon: model.isSaved(detail) ? "bookmark.fill" : "bookmark")
                }
                .buttonStyle(.plain)

                ShareLink(item: detail.shareURL) {
                    ActionLabel(title: "Compartir", icon: "square.and.arrow.up")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var hours: some View {
        DisclosureGroup(isExpanded: $showHours) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(detail.weekdayHours, id: \.self) { line in
                    Text(line).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(Color.konnectBlue)
                    .frame(width: 24)
                Text("Horarios")
            }
        }
    }

    private var reviews: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reseñas").font(.headline)
            ForEach(detail.reviews.prefix(3)) { review in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(review.author).font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "star.fill").foregroundStyle(Color.yellow).font(.caption)
                        Text(review.rating.ratingText).font(.caption)
                    }
                    if !review.text.isEmpty {
                        Text(review.text).font(.footnote).lineLimit(4)
                    }
                    if !review.time.isEmpty {
                        Text(review.time).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
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
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous),
                     tint: prominent ? Color.konnectBlue.opacity(0.8) : Color.glassTint,
                     interactive: true)
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
