import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService

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

                Section {
                    LabeledContent("Estado", value: location.statusText)
                    if location.isAuthorized {
                        LabeledContent("Precisión", value: location.accuracyText)
                    }
                    if location.isDenied {
                        Button("Abrir Ajustes") { location.openSettings() }
                    } else if location.status == .notDetermined {
                        Button("Permitir ubicación") { location.requestPermission() }
                    } else if location.isReduced {
                        Button("Activar ubicación precisa") { location.requestFullAccuracy() }
                    }
                } header: {
                    Text("Ubicación")
                } footer: {
                    Text("Si ves un área en vez de un punto, activa «Ubicación precisa» en Ajustes > Privacidad > Localización > Konnect GPS.")
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
                    Text("Con una clave de Places API (New) verás valoraciones, horarios, fotos y reseñas; para Street View de Google activa también Maps Embed API. Sin clave, la app usa Apple Maps y Look Around. La clave se guarda solo en este iPhone.")
                }

                Section("Mis listas") {
                    ForEach(PlaceList.allCases) { list in
                        LabeledContent {
                            Text("\(model.items(in: list).count)")
                        } label: {
                            Label(list.title, systemImage: list.icon)
                        }
                    }
                    LabeledContent("Búsquedas recientes", value: "\(model.recents.count)")
                }

                Section {
                    Button("Borrar búsquedas recientes", role: .destructive) { model.recents = [] }
                        .disabled(model.recents.isEmpty)
                }

                Section {
                    LabeledContent("Versión", value: "0.3.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(KonnectBackground())
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 96) }
            .navigationTitle("Tú")
        }
    }
}
