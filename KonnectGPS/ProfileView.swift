import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var model: AppModel

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
                Section("Resumen") {
                    LabeledContent("Lugares guardados", value: "\(model.saved.count)")
                    LabeledContent("Búsquedas recientes", value: "\(model.recents.count)")
                }
                Section {
                    Button("Borrar búsquedas recientes", role: .destructive) { model.recents = [] }
                        .disabled(model.recents.isEmpty)
                }
                Section {
                    LabeledContent("Versión", value: "0.1.0")
                }
            }
            .navigationTitle("Tú")
        }
    }
}
