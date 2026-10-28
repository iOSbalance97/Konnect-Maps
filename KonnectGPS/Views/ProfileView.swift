import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @EnvironmentObject var parking: ParkingService
    @EnvironmentObject var radar: RadarService
    @EnvironmentObject var alerts: AlertsService

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

                locationSection
                parkingSection
                radarSection
                googleSection

                Section("Mis listas") {
                    ForEach(PlaceList.allCases) { list in
                        LabeledContent {
                            Text("\(model.items(in: list).count)")
                        } label: {
                            Label(list.title, systemImage: list.icon)
                        }
                    }
                    LabeledContent("Lugares recientes", value: "\(model.recentPlaces.count)")
                    LabeledContent("Búsquedas recientes", value: "\(model.recents.count)")
                }

                Section {
                    Button("Borrar búsquedas recientes", role: .destructive) { model.recents = [] }
                        .disabled(model.recents.isEmpty)
                    Button("Borrar lugares recientes", role: .destructive) { model.recentPlaces = [] }
                        .disabled(model.recentPlaces.isEmpty)
                }

                Section {
                    LabeledContent("Versión", value: "0.4.0")
                }
            }
            .scrollContentBackground(.hidden)
            .background(KonnectBackground())
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 96) }
            .navigationTitle("Tú")
        }
    }

    // MARK: Secciones

    private var locationSection: some View {
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
    }

    private var parkingSection: some View {
        Section {
            Toggle("Detectar coche aparcado", isOn: $parking.isEnabled)
            if let car = parking.parkedCar {
                LabeledContent("Guardado", value: car.date.formatted(date: .abbreviated, time: .shortened))
                Button("Ver mi coche en el mapa") {
                    model.tab = .explore
                    model.selectedPlace = car.place
                }
            }
            Button("Guardar mi posición como coche aparcado") {
                parking.parkHere(location.location)
            }
            .disabled(location.location == nil)
            if parking.parkedCar != nil {
                Button("Borrar coche aparcado", role: .destructive) { parking.clear() }
            }
            if parking.isEnabled && !location.isAlways {
                Button("Permitir ubicación «Siempre»") { location.requestAlways() }
            }
        } header: {
            Text("Coche aparcado")
        } footer: {
            Text("Se guarda al desconectarte del Bluetooth o CarPlay del coche después de conducir, o al alejarte del último punto donde estuvo conectado. Para detectarlo con la app cerrada hace falta el permiso de ubicación «Siempre».")
        }
    }

    private var radarSection: some View {
        Section {
            Toggle("Mostrar radares en el mapa", isOn: $radar.showRadars)
            if let status = radar.status {
                Text(status).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Radares")
        } footer: {
            Text("Datos de OpenStreetMap (colaborativos): pueden no estar al día. Durante la navegación se muestran siempre y avisan por voz.")
        }
    }

    private var googleSection: some View {
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
    }
}
