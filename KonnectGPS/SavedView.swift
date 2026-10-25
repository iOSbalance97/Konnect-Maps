import SwiftUI

struct SavedView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.saved.isEmpty {
                    ContentUnavailableView("Sin lugares guardados",
                                           systemImage: "bookmark",
                                           description: Text("Guarda sitios desde su ficha y aparecerán aquí."))
                } else {
                    List {
                        ForEach(model.saved) { item in
                            Button { model.selectedPlace = item.place } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(Color.konnectBlue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                        if !item.address.isEmpty {
                                            Text(item.address).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                        .onDelete { model.saved.remove(atOffsets: $0) }
                    }
                }
            }
            .navigationTitle("Guardados")
        }
    }
}
