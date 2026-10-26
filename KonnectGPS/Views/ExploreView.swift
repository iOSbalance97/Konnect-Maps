import SwiftUI
import MapKit

struct ExploreView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService

    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(.madrid))
    @State private var showSearch = false
    @State private var showProfile = false
    @State private var pendingPick: Place?
    @State private var is3D = false
    @State private var satellite = false

    private var center: CLLocationCoordinate2D { location.location?.coordinate ?? .madrid }
    private var bottomInset: CGFloat { model.isNavigating ? 8 : 92 }

    var body: some View {
        ZStack {
            map
            VStack(spacing: 10) {
                topArea
                HStack {
                    Spacer()
                    controls
                }
                Spacer()
                bottomArea
            }
            .padding(.horizontal, 12)
            .padding(.bottom, bottomInset)
            .animation(.easeInOut(duration: 0.25), value: model.isNavigating)
        }
        .sheet(isPresented: $showSearch, onDismiss: {
            if let place = pendingPick {
                pendingPick = nil
                model.selectedPlace = place
            }
        }) {
            SearchView(center: center) { place in
                model.places = [place]
                pendingPick = place
            }
            .environmentObject(model)
            .environmentObject(location)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .environmentObject(model)
                .environmentObject(location)
        }
        .task {
            if let loc = location.location { await model.refreshCity(for: loc) }
        }
        .onChange(of: location.location) { _, loc in
            if let loc { Task { await model.refreshCity(for: loc) } }
        }
        .onChange(of: model.places.count) { _, count in
            if count > 0 && model.destination == nil { camera = .automatic }
        }
        .onChange(of: model.selectedPlace?.id) { _, _ in
            if let p = model.selectedPlace {
                camera = .region(MKCoordinateRegion(center: p.coordinate, latitudinalMeters: 900, longitudinalMeters: 900))
            }
        }
        .onChange(of: model.routeVersion) { _, _ in fitRoute() }
        .onChange(of: model.mode) { _, _ in fitRoute() }
        .onChange(of: model.isNavigating) { _, navigating in
            if navigating {
                camera = .userLocation(followsHeading: true, fallback: .automatic)
            } else {
                fitRoute()
            }
        }
    }

    // MARK: Mapa (más oscuro, con nuestro tono azul marino)

    private var currentMapStyle: MapStyle {
        let elevation: MapStyle.Elevation = is3D ? .realistic : .flat
        return satellite ? .hybrid(elevation: elevation) : .standard(elevation: elevation, emphasis: .muted)
    }

    private var map: some View {
        Map(position: $camera) {
            UserAnnotation()
            if let destination = model.destination {
                Marker(destination.name, systemImage: "mappin", coordinate: destination.coordinate)
                    .tint(.red)
                if let route = model.routes[model.mode]?.route {
                    MapPolyline(route.polyline)
                        .stroke(Color.konnectBlue, lineWidth: 7)
                }
            } else {
                ForEach(model.places) { place in
                    Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                        Button { model.selectedPlace = place } label: {
                            Image(systemName: model.activeCategory?.icon ?? "mappin")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 34, height: 34)
                                .background(model.activeCategory?.color ?? Color.red, in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5))
                        }
                    }
                }
            }
        }
        .mapStyle(currentMapStyle)
        .overlay {
            Color.mapTint.opacity(0.22).allowsHitTesting(false)
        }
        .overlay {
            LinearGradient(colors: [Color.black.opacity(0.5), Color.clear, Color.clear, Color.black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private func fitRoute() {
        guard let route = model.routes[model.mode]?.route else { return }
        let rect = route.polyline.boundingMapRect
        camera = .rect(rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.6))
    }

    // MARK: Zona superior

    @ViewBuilder
    private var topArea: some View {
        if model.isNavigating {
            if let route = model.routes[model.mode]?.route {
                NavigationBanner(route: route, userLocation: location.location)
            }
        } else if model.destination == nil {
            GlassGroup(spacing: 6) {
                HStack(spacing: 12) {
                    searchBar
                    GlassCircleButton(icon: "person.fill", size: 52) { showProfile = true }
                }
            }
            chips
            if location.isDenied { deniedBanner }
        }
    }

    private var searchBar: some View {
        Button { showSearch = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                Text("Buscar aquí…").foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "mic.fill").foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(height: 52)
            .liquidGlass(in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlaceCategory.allCases) { category in
                    let active = model.activeCategory == category
                    Button {
                        Task { await model.toggleCategory(category, near: center) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .foregroundStyle(active ? Color.white : category.color)
                            Text(category.title).font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .liquidGlass(in: Capsule(),
                                     tint: active ? category.color.opacity(0.6) : Color.glassTint,
                                     interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var deniedBanner: some View {
        Button { location.openSettings() } label: {
            HStack(spacing: 8) {
                Image(systemName: "location.slash.fill")
                Text("Ubicación desactivada · Activar en Ajustes").font(.footnote.weight(.medium))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .liquidGlass(in: Capsule(), tint: Color.orange.opacity(0.45), interactive: true)
        }
        .buttonStyle(.plain)
    }

    // MARK: Botones laterales

    private var controls: some View {
        GlassGroup(spacing: 8) {
            VStack(spacing: 12) {
                GlassCircleButton(icon: "location.fill", size: 50) {
                    camera = .userLocation(fallback: .region(.madrid))
                }
                GlassCircleButton(icon: "square.3.layers.3d", size: 50, active: satellite) {
                    satellite.toggle()
                }
                GlassCircleButton(text: "3D", size: 50, active: is3D) {
                    toggle3D()
                }
            }
        }
    }

    private func toggle3D() {
        is3D.toggle()
        camera = is3D
            ? .camera(MapCamera(centerCoordinate: center, distance: 1200, heading: 0, pitch: 60))
            : .region(MKCoordinateRegion(center: center, latitudinalMeters: 3000, longitudinalMeters: 3000))
    }

    // MARK: Zona inferior

    @ViewBuilder
    private var bottomArea: some View {
        if let destination = model.destination {
            RoutePanel(destination: destination)
        } else {
            NearbyPanel(center: center)
        }
    }
}
