import SwiftUI

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationManager

    var body: some View {
        TabView(selection: $model.tab) {
            ExploreView()
                .tabItem { Label("Explorar", systemImage: "map.fill") }
                .tag(AppTab.explore)
            SavedView()
                .tabItem { Label("Guardados", systemImage: "bookmark.fill") }
                .tag(AppTab.saved)
            ProfileView()
                .tabItem { Label("Tú", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .tint(.konnectBlue)
        .sheet(item: $model.selectedPlace) { place in
            PlaceDetailView(place: place)
                .environmentObject(model)
                .environmentObject(location)
        }
    }
}
