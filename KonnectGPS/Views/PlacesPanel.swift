import SwiftUI
import CoreLocation

/// "Lugares": barra globo plegada que se abre/cierra pulsando y arrastrando.
/// Pestañas interiores: Favoritos, Guardados y Sitios relevantes (+ Resultados de búsqueda).
struct PlacesPanel: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService

    @State private var expanded = false
    @State private var drag: CGFloat = 0
    @State private var isDraggingVertically = false
    @State private var selectedList: PlaceList = .favorites
    @State private var showingResults = false

    private let collapsedHeight: CGFloat = 60
    private let fullHeight: CGFloat = 292
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
        if showingResults && !model.places.isEmpty { return "\(model.places.count) resultados" }
        let count = model.items(in: selectedList).count
        return "\(selectedList.title) · \(count)"
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
            showingResults = !isEmpty
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { expanded = !isEmpty }
        }
    }

    // MARK: Gesto (toda la barra se arrastra; solo cuenta el movimiento vertical)

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
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
        VStack(spacing: 6) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 36, height: 4)
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(Color.konnectBlue)
                Text("Lugares").font(.headline)
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
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { expanded.toggle() }
        }
    }

    // MARK: Pestañas interiores

    private var tabsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if !model.places.isEmpty {
                    pill(title: "Resultados", icon: "magnifyingglass", selected: showingResults) {
                        showingResults = true
                    }
                }
                ForEach(PlaceList.allCases) { list in
                    pill(title: list.title, icon: list.icon, selected: !showingResults && selectedList == list) {
                        showingResults = false
                        selectedList = list
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 36)
    }

    private func pill(title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title).lineLimit(1)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(selected ? Color.konnectBlue.opacity(0.75) : Color.white.opacity(0.10), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
    }

    // MARK: Contenido

    private var cardsHeight: CGFloat { range - 36 - 10 - 14 }

    private func cardsScroll<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) { content() }
                .padding(.horizontal, 16)
        }
        .frame(height: cardsHeight)
    }

    @ViewBuilder
    private var content: some View {
        if showingResults && !model.places.isEmpty {
            cardsScroll {
                ForEach(model.places.prefix(15)) { place in
                    PlaceCard(place: place,
                              distance: place.distance(from: location.location),
                              icon: model.activeCategory?.icon ?? "mappin.circle.fill",
                              color: model.activeCategory?.color ?? Color.konnectBlue) {
                        model.selectedPlace = place
                    }
                }
            }
        } else {
            let items = model.items(in: selectedList)
            if items.isEmpty {
                emptyState
            } else {
                cardsScroll {
                    ForEach(items) { item in
                        let place = item.place
                        PlaceCard(place: place,
                                  distance: place.distance(from: location.location),
                                  icon: selectedList.icon,
                                  color: selectedList.color) {
                            model.selectedPlace = place
                        }
                        .contextMenu {
                            Button("Quitar de \(selectedList.title)", role: .destructive) {
                                model.remove(item, from: selectedList)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedList.icon)
                .font(.system(size: 28))
                .foregroundStyle(selectedList.color)
            Text("Aún no hay sitios en \(selectedList.title)")
                .font(.subheadline.weight(.semibold))
            Text("Abre la ficha de un lugar y pulsa Guardar para añadirlo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .frame(height: cardsHeight)
    }
}

struct PlaceCard: View {
    let place: Place
    let distance: String?
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: icon).foregroundStyle(color)
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
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white)
            .padding(12)
            .frame(width: 170, height: 112, alignment: .topLeading)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}
