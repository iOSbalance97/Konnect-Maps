import SwiftUI
import MapKit
import UIKit

enum SearchTarget: String, Identifiable {
    case search, origin, destination
    var id: String { rawValue }
    var title: String {
        switch self {
        case .search: return "Buscar lugares"
        case .origin: return "Elegir origen"
        case .destination: return "Elegir destino"
        }
    }
}

struct ExploreView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @EnvironmentObject var nav: NavigationEngine

    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(.madrid))
    @State private var searchTarget: SearchTarget?
    @State private var pendingPick: Place?
    @State private var showSteps = false
    @State private var is3D = false
    @State private var satellite = false
    @State private var followMode = true
    @State private var lastHeading: Double = 0
    @State private var pressOrigin: CGPoint?
    @State private var pressTask: Task<Void, Never>?

    private var center: CLLocationCoordinate2D { location.location?.coordinate ?? .madrid }
    private var bottomInset: CGFloat { model.isNavigating ? 8 : 92 }

    var body: some View {
        ZStack {
            mapLayer
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
        .sheet(item: $searchTarget, onDismiss: {
            if let place = pendingPick {
                pendingPick = nil
                model.selectedPlace = place
            }
        }) { target in
            SearchView(center: center, title: target.title, allowCurrentLocation: target == .origin) { place in
                handlePick(place, target: target)
            }
            .environmentObject(model)
            .environmentObject(location)
        }
        .sheet(isPresented: $showSteps) {
            RouteStepsView()
                .environmentObject(model)
        }
        .task {
            if let loc = location.location { await model.refreshCity(for: loc) }
        }
        .onChange(of: location.location) { _, loc in
            guard let loc else { return }
            Task { await model.refreshCity(for: loc) }
            if model.isNavigating {
                nav.update(with: loc)
                if followMode { followCamera(loc) }
            }
        }
        .onChange(of: nav.needsReroute) { _, needs in
            guard needs, let loc = location.location else { return }
            Task {
                await model.reroute(from: loc.coordinate)
                if let route = model.routes[model.mode]?.route {
                    nav.start(route: route)
                } else {
                    nav.resetOffRoute()
                }
            }
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
            UIApplication.shared.isIdleTimerDisabled = navigating
            location.setNavigating(navigating)
            if navigating {
                followMode = true
                if let route = model.routes[model.mode]?.route { nav.start(route: route) }
                if let loc = location.location { followCamera(loc) }
            } else {
                nav.stop()
                if model.destination == nil {
                    camera = .userLocation(fallback: .region(.madrid))
                } else {
                    fitRoute()
                }
            }
        }
    }

    // MARK: Mapa (más oscuro, con nuestro tono azul marino)

    private var currentMapStyle: MapStyle {
        let elevation: MapStyle.Elevation = is3D ? .realistic : .flat
        return satellite ? .hybrid(elevation: elevation) : .standard(elevation: elevation, emphasis: .muted)
    }

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $camera) {
                // Tu posición: punto exacto, sin área de imprecisión.
                if let loc = location.location {
                    Annotation("", coordinate: loc.coordinate, anchor: .center) {
                        UserDot(store: location.headingStore, navigating: model.isNavigating)
                    }
                }
                if let pin = model.droppedPin, model.destination == nil {
                    Marker(pin.name, systemImage: "mappin", coordinate: pin.coordinate)
                        .tint(.red)
                }
                if let destination = model.destination {
                    if let origin = model.origin {
                        Marker(origin.name, systemImage: "circle.fill", coordinate: origin.coordinate)
                            .tint(.green)
                    }
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
            .simultaneousGesture(longPressGesture(proxy))
        }
    }

    /// Dejar pulsado un punto del mapa abre su dirección.
    private func longPressGesture(_ proxy: MapProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard !model.isNavigating else { return }
                if let origin = pressOrigin {
                    let moved = hypot(value.location.x - origin.x, value.location.y - origin.y)
                    if moved > 12 { pressTask?.cancel() }
                } else {
                    pressOrigin = value.location
                    let point = value.location
                    pressTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(550))
                        guard !Task.isCancelled else { return }
                        if let coordinate = proxy.convert(point, from: .local) {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            await model.dropPin(at: coordinate)
                        }
                    }
                }
            }
            .onEnded { _ in
                pressTask?.cancel()
                pressOrigin = nil
            }
    }

    private func fitRoute() {
        guard let route = model.routes[model.mode]?.route else { return }
        let rect = route.polyline.boundingMapRect
        camera = .rect(rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.6))
    }

    private func followCamera(_ loc: CLLocation) {
        let course = loc.course >= 0 ? loc.course : lastHeading
        lastHeading = course
        withAnimation(.linear(duration: 0.9)) {
            camera = .camera(MapCamera(centerCoordinate: loc.coordinate, distance: 500, heading: course, pitch: 55))
        }
    }

    private func handlePick(_ place: Place?, target: SearchTarget) {
        switch target {
        case .search:
            guard let place else { return }
            model.places = [place]
            pendingPick = place
        case .origin:
            Task { await model.setOrigin(place, userCoordinate: center) }
        case .destination:
            guard let place else { return }
            Task { await model.setDestination(place, userCoordinate: center) }
        }
    }

    // MARK: Zona superior

    @ViewBuilder
    private var topArea: some View {
        if model.isNavigating {
            NavigationBanner()
        } else if model.destination != nil {
            RoutePlannerCard(onEditOrigin: { searchTarget = .origin },
                             onEditDestination: { searchTarget = .destination })
        } else {
            searchBar
            chips
            locationBanner
        }
    }

    /// La barra de búsqueda ocupa todo el ancho.
    private var searchBar: some View {
        Button { searchTarget = .search } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                Text("Buscar aquí…").foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "mic.fill").foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .liquidGlass(in: Capsule())
        }
        .buttonStyle(.pressable)
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
                                     tint: active ? category.color.opacity(0.6) : Color.glassTint)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var locationBanner: some View {
        if location.isDenied {
            banner(icon: "location.slash.fill", text: "Ubicación desactivada · Activar en Ajustes") {
                location.openSettings()
            }
        } else if location.isReduced {
            banner(icon: "location.circle", text: "Ubicación aproximada · Activar precisa") {
                location.requestFullAccuracy()
            }
        }
    }

    private func banner(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(text).font(.footnote.weight(.medium))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .liquidGlass(in: Capsule(), tint: Color.orange.opacity(0.45))
        }
        .buttonStyle(.pressable)
    }

    // MARK: Botones laterales

    private var controls: some View {
        GlassGroup(spacing: 8) {
            VStack(spacing: 12) {
                if model.isNavigating {
                    GlassCircleButton(icon: nav.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                      size: 50, active: !nav.isMuted) {
                        nav.isMuted.toggle()
                    }
                    GlassCircleButton(icon: followMode ? "arrow.up.left.and.arrow.down.right" : "location.north.fill",
                                      size: 50, active: !followMode) {
                        toggleFollow()
                    }
                } else {
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
    }

    private func toggleFollow() {
        followMode.toggle()
        if followMode, let loc = location.location {
            followCamera(loc)
        } else {
            fitRoute()
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
        if model.isNavigating {
            NavigationBottomBar()
        } else if let destination = model.destination {
            RoutePanel(destination: destination, showSteps: $showSteps)
        } else {
            PlacesPanel()
        }
    }
}
