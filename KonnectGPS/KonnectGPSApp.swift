import SwiftUI

@main
struct KonnectGPSApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var location = LocationService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(location)
                .preferredColorScheme(.dark)
        }
    }
}
