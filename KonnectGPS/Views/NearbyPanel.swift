import SwiftUI
import CoreLocation

/// "Cerca de ti": barra globo plegada que se abre/cierra pulsando y arrastrando.
struct NearbyPanel: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    let center: CLLocationCoordinate2D

    @State private var expanded = false
    @State private var drag: CGFloat = 0

    private let collapsedHeight: CGFloat = 60
    private let fullHeight: CGFloat = 238
    private var range: CGFloat { fullHeight - collapsedHeight }

    /// 0 = plegado, 1 = abierto. Sigue al dedo mientras se arrastra.
    private var progress: CGFloat {
        let base: CGFloat = expanded ? 1 : 0
        return min(max(base - drag / range, 0), 1)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    private var subtitle: String {
        if model.places.isEmpty {
            if let city = model.cityName { return "en \(city)" }
            return "sitios populares"
        }
        return "\(model.places.count) lugares"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            cards
                .opacity(Double(progress))
                .allowsHitTesting(progress > 0.95)
        }
        .frame(maxWidth: .infinity)
        .frame(height: collapsedHeight + range * progress, alignment: .top)
        .clipShape(shape)
        .liquidGlass(in: shape)
        .onChange(of: model.places.isEmpty) { _, isEmpty in
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) { expanded = !isEmpty }
        }
    }

    // MARK: Cabecera (la barra que se arrastra)

    private var header: some View {
        VStack(spacing: 6) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 36, height: 4)
            HStack(spacing: 8) {
                Image(systemName: "location.circle.fill")
                    .foregroundStyle(Color.konnectBlue)
                Text(model.places.isEmpty ? "Cerca de ti" : "Resultados")
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if !model.places.isEmpty {
                    Button("Limpiar") { model.clearResults() }
                        .font(.subheadline)
                }
                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(Double(progress) * 180))
            }
        }
        .padding(.top, 8)
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
        .frame(height: collapsedHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(duration: 0.4, bounce: 0.2)) { expanded.toggle() }
        }
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    drag = value.translation.height
                }
                .onEnded { value in
                    let base = CGFloat(expanded ? 1 : 0)
                    let projected = base - value.predictedEndTranslation.height / range
                    withAnimation(.spring(duration: 0.4, bounce: 0.2)) {
                        expanded = projected > 0.5
                        drag = 0
                    }
                }
        )
    }

    // MARK: Contenido

    private var cards: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                if model.places.isEmpty {
                    ForEach(PlaceCategory.allCases) { category in
                        CategoryCard(category: category) {
                            Task { await model.toggleCategory(category, near: center) }
                        }
                    }
                } else {
                    ForEach(model.places.prefix(15)) { place in
                        PlaceCard(place: place,
                                  distance: place.distance(from: location.location),
                                  category: model.activeCategory) {
                            model.selectedPlace = place
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: fullHeight - collapsedHeight)
    }
}

struct CategoryCard: View {
    let category: PlaceCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [category.color.opacity(0.9), category.color.opacity(0.35)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: category.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(Color.white)
                }
                .frame(height: 64)
                Text(category.title).font(.subheadline.weight(.semibold))
                Text("Ver cercanos").font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(width: 150, alignment: .leading)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct PlaceCard: View {
    let place: Place
    let distance: String?
    let category: PlaceCategory?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: category?.icon ?? "mappin.circle.fill")
                        .foregroundStyle(category?.color ?? Color.konnectBlue)
                    Spacer()
                    if let distance {
                        Text(distance).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(place.categoryText).font(.caption).foregroundStyle(.secondary)
                if let rating = place.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundStyle(Color.yellow)
                        Text(rating.ratingText)
                    }
                    .font(.caption)
                }
            }
            .padding(12)
            .frame(width: 170, alignment: .leading)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
