import SwiftUI

/// Un único globo flotante: en el mapa muestra "Tú"; en "Tú" muestra el mapa.
struct TabBubble: View {
    @Binding var tab: AppTab

    var body: some View {
        let toProfile = tab == .explore
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                tab = toProfile ? .profile : .explore
            }
        } label: {
            Image(systemName: toProfile ? "person.fill" : "map.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 70, height: 70)
                .liquidGlass(in: Circle(), tint: Color.glassTint)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(toProfile ? "Tú" : "Mapa")
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @EnvironmentObject var parking: ParkingService
    @Environment(\.verticalSizeClass) private var vSize

    private var landscape: Bool { vSize == .compact }

    var body: some View {
        ZStack(alignment: landscape ? .bottomTrailing : .bottom) {
            // El mapa se mantiene vivo al cambiar de sección.
            ExploreView()
                .opacity(model.tab == .explore ? 1 : 0)
                .allowsHitTesting(model.tab == .explore)

            if model.tab == .profile {
                ProfileView()
                    .transition(.opacity)
            }

            if !model.isNavigating {
                TabBubble(tab: $model.tab)
                    .padding(.bottom, 8)
                    .padding(.trailing, landscape ? 12 : 0)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.tab)
        .animation(.easeInOut(duration: 0.25), value: model.isNavigating)
        .tint(.konnectBlue)
        .sheet(item: $model.selectedPlace, onDismiss: {
            model.droppedPin = nil
        }) { place in
            PlaceDetailView(place: place)
                .environmentObject(model)
                .environmentObject(location)
                .environmentObject(parking)
        }
    }
}
