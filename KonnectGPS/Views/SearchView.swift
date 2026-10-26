import SwiftUI
import MapKit

struct SearchView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @Environment(\.dismiss) private var dismiss

    let center: CLLocationCoordinate2D
    let onPick: (Place) -> Void

    @State private var text = ""
    @State private var results: [Place] = []
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Buscar lugares", text: $text)
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
                    if !model.recents.isEmpty {
                        Section {
                            ForEach(model.recents, id: \.self) { recent in
                                Button { text = recent } label: {
                                    Label(recent, systemImage: "clock.arrow.circlepath")
                                }
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
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .darkSheetBackground()
        .onAppear { focused = true }
        .onChange(of: text) { _, newValue in
            searchTask?.cancel()
            searchTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
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
        return parts.joined(separator: " · ")
    }

    private func submit() {
        let query = text
        model.addRecent(query)
        Task { @MainActor in
            let found = await model.query(query, near: center)
            model.places = found
            model.activeCategory = nil
            dismiss()
        }
    }
}
