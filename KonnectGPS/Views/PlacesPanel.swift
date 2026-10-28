import SwiftUI
import CoreLocation

enum PanelTab: Hashable {
    case recents, results
    case list(PlaceList)
}

/// "Lugares": barra globo plegada que se abre/cierra pulsando y arrastrando.
/// Pestañas: Recientes, (Resultados), Favoritos, Guardados y Sitios relevantes.
struct PlacesPanel: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @Environment(\.verticalSizeClass) private var vSize

    @State private var expanded = false
    @State private var drag: CGFloat = 0
    @State private var isDraggingVertically = false
    @State private var selected: PanelTab = .recents

    private var landscape: Bool { vSize == .compact }
    private var collapsedHeight: CGFloat { landscape ? 58 : 70 }
    private var fullHeight: CGFloat { landscape ? 238 : 376 }
    private var cardWidth: CGFloat { landscape ? 196 : 218 }
    private var cardHeight: CGFloat { landscape ? 112 : 150 }
    private var pillHeight: CGFloat { landscape ? 34 : 42 }
    private var range: CGFloat { fullHeight - collapsedHeight }
    private var cardsHeight: CGFloat { range - pillHeight - 10 - 18 }

    /// 0 = plegado, 1 = abierto. Sigue al dedo mientras se arrastra.
    private var progress: CGFloat {
        let base: CGFloat = expanded ? 1 : 0
        return min(max(base - drag / range, 0), 1)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
    }

    private var subtitle: String {
        switch selected {
        case .recents: return "Recientes · \(model.recentPlaces.count)"
        case .results: return "\(model.places.count) resultados"
        case .list(let list): return "\(list.title) · \(model.items(in: list).count)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 10) {
                tabsRow
                content
            }
            .opacity(Double(progress))
            .allowsHitTesting(progress > 0.95)
        }
        .frame(maxWidth: .infinity)
        .frame(height: collapsedHeight + range * progress, alignment: .top)
        .clipShape(shape)
        .liquidGlass(in: shape)
        .simultaneousGesture(dragGesture)
        .onChange(of: model.places.isEmpty) { _, isEmpty in
            if isEmpty {
                if selected == .results { selected = .recents }
            } else {
                selected = .results
            }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { expanded = !isEmpty }
        }
    }

    // MARK: Gesto
    // IMPORTANTE: el espacio de coordenadas es global. Con el local, al cambiar la altura
    // del panel cambiaba el origen del gesto y la barra "temblaba".

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                if !isDraggingVertically {
                    guard abs(value.translation.height) > abs(value.translation.width) else { return }
                    isDraggingVertically = true
                }
                drag = value.translation.height
            }
            .onEnded { value in
                guard isDraggingVertically else { return }
                isDraggingVertically = false
                let base = CGFloat(expanded ? 1 : 0)
                let projected = base - value.predictedEndTranslation.height / range
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    expanded = projected > 0.5
                    drag = 0
                }
            }
    }

    // MARK: Cabecera

    private var header: some View {
        VStack(spacing: 7) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 40, height: 5)
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title3)
                    .foregroundStyle(Color.konnectBlue)
                Text("Lugares").font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if !model.places.isEmpty {
                    Button("Limpiar") { model.clearResults() }
                        .font(.subheadline.weight(.semibold))
                }
                Image(systemName: "chevron.up")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(Double(progress) * 180))
            }
        }
        .padding(.top, 9)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .frame(height: collapsedHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { expanded.toggle() }
        }
    }

    // MARK: Pestañas interiores

    private var tabsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                pill(title: "Recientes", icon: "clock.fill", tab: .recents)
                if !model.places.isEmpty {
                    pill(title: "Resultados", icon: "magnifyingglass", tab: .results)
                }
                ForEach(PlaceList.allCases) { list in
                    pill(title: list.title, icon: list.icon, tab: .list(list))
                }
            }
            .padding(.horizontal, 22)
        }
        .frame(height: pillHeight)
        .horizontalFade(20)
    }

    private func pill(title: String, icon: String, tab: PanelTab) -> some View {
        let isSelected = selected == tab
        return Button { selected = tab } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 15)
            .frame(height: pillHeight)
            .background(isSelected ? Color.konnectBlue.opacity(0.8) : Color.white.opacity(0.10), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
    }

    // MARK: Contenido

    private func cardsScroll<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) { content() }
                .padding(.horizontal, 22)
        }
        .frame(height: cardsHeight)
        .horizontalFade(20)
    }

    private func card(for place: Place, icon: String, color: Color) -> some View {
        PlaceCard(place: place,
                  distance: place.distance(from: location.location),
                  icon: icon, color: color,
                  width: cardWidth, height: cardHeight) {
            model.selectedPlace = place
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selected {
        case .results:
            if model.places.isEmpty {
                emptyState(icon: "magnifyingglass", title: "Sin resultados",
                           text: "Busca un lugar o elige una categoría.")
            } else {
                cardsScroll {
                    ForEach(model.places.prefix(15)) { place in
                        card(for: place,
                             icon: model.activeCategory?.icon ?? "mappin.circle.fill",
                             color: model.activeCategory?.color ?? Color.konnectBlue)
                    }
                }
            }
        case .recents:
            if model.recentPlaces.isEmpty {
                emptyState(icon: "clock.arrow.circlepath", title: "Aún no hay lugares recientes",
                           text: "Los sitios que busques o abras aparecerán aquí.")
            } else {
                cardsScroll {
                    ForEach(model.recentPlaces) { item in
                        card(for: item.place, icon: "clock.fill", color: Color.white.opacity(0.75))
                            .contextMenu {
                                Button("Quitar de recientes", role: .destructive) {
                                    model.removeRecentPlace(item)
                                }
                            }
                    }
                }
            }
        case .list(let list):
            let items = model.items(in: list)
            if items.isEmpty {
                emptyState(icon: list.icon, title: "Aún no hay sitios en \(list.title)",
                           text: "Abre la ficha de un lugar y pulsa Guardar para añadirlo.")
            } else {
                cardsScroll {
                    ForEach(items) { item in
                        card(for: item.place, icon: list.icon, color: list.color)
                            .contextMenu {
                                Button("Quitar de \(list.title)", role: .destructive) {
                                    model.remove(item, from: list)
                                }
                            }
                    }
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(Color.konnectBlue)
            Text(title).font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .frame(height: cardsHeight)
    }
}

struct PlaceCard: View {
    let place: Place
    let distance: String?
    let icon: String
    let color: Color
    var width: CGFloat = 218
    var height: CGFloat = 150
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                    Spacer()
                    if let distance {
                        Text(distance).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Text(place.name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(place.categoryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let rating = place.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").foregroundStyle(Color.yellow)
                        Text(rating.ratingText)
                    }
                    .font(.subheadline)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white)
            .padding(14)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}
