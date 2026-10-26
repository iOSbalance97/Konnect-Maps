import SwiftUI

struct SavedView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            KonnectBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Guardados")
                        .font(.largeTitle.bold())
                        .padding(.bottom, 4)

                    if model.saved.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 36))
                                .foregroundStyle(Color.konnectBlue)
                            Text("Sin lugares guardados").font(.headline)
                            Text("Guarda sitios desde su ficha y aparecerán aquí.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(28)
                        .liquidGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    } else {
                        GlassGroup(spacing: 8) {
                            VStack(spacing: 12) {
                                ForEach(model.saved) { item in
                                    row(for: item)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
        }
    }

    private func row(for item: SavedPlace) -> some View {
        HStack(spacing: 12) {
            Button { model.selectedPlace = item.place } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(Color.konnectBlue)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.body.weight(.medium))
                        if !item.address.isEmpty {
                            Text(item.address)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { model.removeSaved(item) } label: {
                Image(systemName: "trash")
                    .foregroundStyle(Color.red.opacity(0.9))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
