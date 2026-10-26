import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @Environment(\.dismiss) private var dismiss

    @AppStorage(GoogleConfig.storageKey) private var googleKey = ""
    @State private var testing = false

    private var keyIsEmpty: Bool {
        googleKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(Color.konnectBlue)
                        VStack(alignment: .leading) {
                            Text("Konnect GPS").font(.headline)
                            Text("Tu perfil local").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Ubicación") {
                    LabeledContent("Estado", value: location.statusText)
                    if location.isDenied {
                        Button("Abrir Ajustes") { location.openSettings() }
                    } else if location.status == .notDetermined {
                        Button("Permitir ubicación") { location.requestPermission() }
                    }
                }

                Section {
                    SecureField("Clave de API de Google", text: $googleKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task {
                            testing = true
                            await model.testGoogle(near: location.location?.coordinate ?? .madrid)
                            testing = false
                        }
                    } label: {
                        HStack {
                            Text("Probar conexión")
                            if testing { ProgressView() }
                        }
                    }
                    .disabled(keyIsEmpty || testing)
                    if let message = model.googleMessage {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Google Maps")
                } footer: {
                    Text("Con una clave de Places API (New) verás valoraciones, horarios, fotos y reseñas. Sin clave, la app usa solo Apple Maps. La clave se guarda únicamente en este iPhone.")
                }

                Section("Resumen") {
                    LabeledContent("Lugares guardados", value: "\(model.saved.count)")
                    LabeledContent("Búsquedas recientes", value: "\(model.recents.count)")
                }

                Section {
                    Button("Borrar búsquedas recientes", role: .destructive) { model.recents = [] }
                        .disabled(model.recents.isEmpty)
                }

                Section {
                    LabeledContent("Versión", value: "0.2.0")
                }
            }
            .navigationTitle("Tú")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .darkSheetBackground()
    }
}
