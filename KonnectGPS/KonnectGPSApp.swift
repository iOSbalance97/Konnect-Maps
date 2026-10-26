import SwiftUI

@main
struct KonnectGPSApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var location = LocationService()
    @StateObject private var nav = NavigationEngine()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(location)
                .environmentObject(nav)
                .preferredColorScheme(.dark)
        }
    }
}
