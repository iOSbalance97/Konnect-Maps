import SwiftUI

@main
struct KonnectGPSApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var location = LocationService()
    @StateObject private var nav = NavigationEngine()
    @StateObject private var parking = ParkingService()
    @StateObject private var radar = RadarService()
    @StateObject private var alerts = AlertsService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(location)
                .environmentObject(nav)
                .environmentObject(parking)
                .environmentObject(radar)
                .environmentObject(alerts)
                .preferredColorScheme(.dark)
                .task { parking.attach(to: location) }
        }
    }
}
