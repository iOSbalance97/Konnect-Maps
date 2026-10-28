import SwiftUI
import CoreLocation

/// Búsqueda dentro del mapa: las recientes salen bajo la barra y,
/// al escribir, aparecen los resultados parecidos.
struct SearchOverlay: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @Environment(\.verticalSizeClass) private var vSize

    @Binding var text: String
    let center: CLLocationCoordinate2D
    let onPick: (Place) -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void

    @State private var results: [Place] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private var isEmptyQuery: Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var maxCardHeight: CGFloat { vSize == .compact ? 150 : 360 }

    private var rowCount: Int {
        if isEmptyQuery { return max(model.recents.count + 1, 1) }
        return max(results.count, 1)
    }

    var body: some View {
        VStack(spacing: 10) {
            bar
            card
        }
        .onAppear { focused = true }
        .onChange(of: text) { _, newValue in
            searchTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                results = []
                isLoading = false
                return
            }
            isLoading = true
            searchTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                let found = await model.query(trimmed, near: center)
                guard !Task.isCancelled else { return }
                results = found
                isLoading = false
            }
        }
    }

    // MARK: Barra

    private var bar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                TextField("Buscar aquí…", text: $text)
                    .focused($focused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onSubmit(onSubmit)
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .liquidGlass(in: Capsule())

            Button("Cancelar", action: onCancel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
        }
    }

    // MARK: Tarjeta bajo la barra

    private var card: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if isEmptyQuery {
                    recentsContent
                } else {
                    suggestionsContent
                }
            }
            .padding(.vertical, 6)
        }
        .frame(height: min(CGFloat(rowCount) * 56 + 16, maxCardHeight))
        .liquidGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var recentsContent: some View {
        if model.recents.isEmpty {
            Text("Escribe para buscar lugares y direcciones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(18)
        } else {
            HStack {
                Text("Recientes").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("Limpiar") { model.recents = [] }.font(.footnote)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)

            ForEach(model.recents, id: \.self) { recent in
                row(icon: "clock.arrow.circlepath", color: Color.white.opacity(0.7), title: recent, subtitle: nil) {
                    text = recent
                }
            }
        }
    }

    @ViewBuilder
    private var suggestionsContent: some View {
        if results.isEmpty {
            HStack(spacing: 10) {
                if isLoading { ProgressView() }
                Text(isLoading ? "Buscando…" : "Sin resultados")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(18)
        } else {
            ForEach(results) { place in
                row(icon: "mappin.circle.fill", color: Color.konnectBlue,
                    title: place.name, subtitle: subtitle(for: place)) {
                    model.addRecent(text)
                    onPick(place)
                }
            }
        }
    }

    private func row(icon: String, color: Color, title: String, subtitle: String?,
                     action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).lineLimit(1)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for place: Place) -> String {
        var parts: [String] = []
        if let rating = place.rating { parts.append("★ \(rating.ratingText)") }
        parts.append(place.categoryText)
        if let d = place.distance(from: location.location) { parts.append(d) }
        if !place.address.isEmpty { parts.append(place.address) }
        return parts.joined(separator: " · ")
    }
}
