import SwiftUI

struct BarItem: Identifiable {
    let tab: AppTab
    let icon: String
    let title: String
    var id: AppTab { tab }
}

/// Barra inferior: globos circulares flotantes de cristal.
struct BubbleBar: View {
    @Binding var tab: AppTab

    private let items: [BarItem] = [
        BarItem(tab: .explore, icon: "map.fill", title: "Explorar"),
        BarItem(tab: .saved, icon: "bookmark.fill", title: "Guardados")
    ]

    var body: some View {
        GlassGroup(spacing: 10) {
            HStack(spacing: 24) {
                ForEach(items) { item in
                    Button {
                        withAnimation(.spring(duration: 0.35, bounce: 0.25)) { tab = item.tab }
                    } label: {
                        Image(systemName: item.icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 68, height: 68)
                            .liquidGlass(in: Circle(),
                                         tint: tab == item.tab ? Color.konnectBlue.opacity(0.75) : Color.glassTint,
                                         interactive: true)
                            .scaleEffect(tab == item.tab ? 1.06 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService

    var body: some View {
        ZStack(alignment: .bottom) {
            // El mapa se mantiene vivo al cambiar de sección.
            ExploreView()
                .opacity(model.tab == .explore ? 1 : 0)
                .allowsHitTesting(model.tab == .explore)

            if model.tab == .saved {
                SavedView()
                    .transition(.opacity)
            }

            if !model.isNavigating {
                BubbleBar(tab: $model.tab)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.tab)
        .animation(.easeInOut(duration: 0.25), value: model.isNavigating)
        .tint(.konnectBlue)
        .sheet(item: $model.selectedPlace) { place in
            PlaceDetailView(place: place)
                .environmentObject(model)
                .environmentObject(location)
        }
    }
}
