import SwiftUI
import MapKit

/// Selector de origen/destino (hoja con cristal esmerilado sutil).
struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @Environment(\.dismiss) private var dismiss

    let center: CLLocationCoordinate2D
    var title: String = "Buscar lugares"
    var allowCurrentLocation = false
    /// nil = "Mi ubicación"
    let onPick: (Place?) -> Void

    @State private var text = ""
    @State private var results: [Place] = []
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .padding(.vertical, 3)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(title, text: $text)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .onSubmit(submit)
                    if !text.isEmpty {
                        Button { text = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .liquidGlass(in: Capsule())

                Button("Cancelar") { dismiss() }
            }
            .padding()

            List {
                if text.trimmingCharacters(in: .whitespaces).isEmpty {
                    if allowCurrentLocation {
                        Button {
                            onPick(nil)
                            dismiss()
                        } label: {
                            Label("Mi ubicación", systemImage: "location.fill")
                        }
                        .listRowBackground(rowBackground)
                    }
                    if !model.recents.isEmpty {
                        Section {
                            ForEach(model.recents, id: \.self) { recent in
                                Button { text = recent } label: {
                                    Label(recent, systemImage: "clock.arrow.circlepath")
                                }
                                .listRowBackground(rowBackground)
                            }
                        } header: {
                            HStack {
                                Text("Búsquedas recientes")
                                Spacer()
                                Button("Limpiar") { model.recents = [] }
                            }
                        }
                    }
                } else {
                    ForEach(results) { place in
                        Button {
                            model.addRecent(text)
                            onPick(place)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Color.konnectBlue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                    Text(subtitle(for: place))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .listRowBackground(rowBackground)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .subtleGlassSheet()
        .onAppear { focused = true }
        .onChange(of: text) { _, newValue in
            searchTask?.cancel()
            searchTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                let found = await model.query(newValue, near: center)
                guard !Task.isCancelled else { return }
                results = found
            }
        }
    }

    private func subtitle(for place: Place) -> String {
        var parts: [String] = []
        if let rating = place.rating { parts.append("★ \(rating.ratingText)") }
        parts.append(place.categoryText)
        if let d = place.distance(from: location.location) { parts.append(d) }
        if !place.address.isEmpty { parts.append(place.address) }
        return parts.joined(separator: " · ")
    }

    /// Intro: elige el primer resultado.
    private func submit() {
        let query = text
        model.addRecent(query)
        Task { @MainActor in
            let found = await model.query(query, near: center)
            if let first = found.first {
                onPick(first)
                dismiss()
            }
        }
    }
}
