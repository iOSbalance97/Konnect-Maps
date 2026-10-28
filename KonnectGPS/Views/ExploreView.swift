import SwiftUI
import MapKit
import UIKit

enum SearchTarget: String, Identifiable {
    case origin, destination
    var id: String { rawValue }
    var title: String {
        switch self {
        case .origin: return "Elegir origen"
        case .destination: return "Elegir destino"
        }
    }
}

struct ExploreView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    @EnvironmentObject var nav: NavigationEngine
    @EnvironmentObject var parking: ParkingService
    @EnvironmentObject var radar: RadarService
    @EnvironmentObject var alerts: AlertsService
    @Environment(\.verticalSizeClass) private var vSize

    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(.madrid))
    @State private var searchTarget: SearchTarget?
    @State private var isSearching = false
    @State private var searchText = ""
    @State private var showSteps = false
    @State private var showReport = false
    @State private var selectedAlert: RoadAlert?
    @State private var is3D = false
    @State private var satellite = false
    @State private var followMode = true
    @State private var lastHeading: Double = 0
    @State private var visibleCenter: CLLocationCoordinate2D?
    @State private var pressOrigin: CGPoint?
    @State private var pressTask: Task<Void, Never>?

    private var landscape: Bool { vSize == .compact }
    private var center: CLLocationCoordinate2D { location.location?.coordinate ?? .madrid }
    private var bottomInset: CGFloat { (model.isNavigating || landscape) ? 8 : 92 }
    private var controlSize: CGFloat { landscape ? 44 : 50 }

    var body: some View {
        ZStack {
            mapLayer
            overlayLayout
                .padding(.horizontal, 12)
                .padding(.bottom, bottomInset)
                .animation(.easeInOut(duration: 0.25), value: model.isNavigating)
        }
        .sheet(item: $searchTarget) { target in
            SearchView(center: center, title: target.title, allowCurrentLocation: target == .origin) { place in
                handlePick(place, target: target)
            }
            .environmentObject(model)
            .environmentObject(location)
        }
        .sheet(isPresented: $showSteps) {
            RouteStepsView()
                .environmentObject(model)
                .environmentObject(nav)
        }
        .sheet(isPresented: $showReport) {
            AlertReportView(coordinate: center)
                .environmentObject(alerts)
        }
        .sheet(item: $selectedAlert) { alert in
            AlertDetailView(alert: alert)
                .environmentObject(alerts)
        }
        .task {
            if let loc = location.location { await model.refreshCity(for: loc) }
        }
        .onChange(of: location.location) { _, loc in
            guard let loc else { return }
            Task { await model.refreshCity(for: loc) }
            if model.isNavigating {
                nav.update(with: loc)
                nav.checkHazards(currentHazards(), at: loc)
                Task { await radar.refreshIfNeeded(near: loc) }
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
                model.noteVisited(p)
                // El lugar queda en la parte alta de la pantalla, sobre la ficha baja.
                let shift = 900.0 * 0.15 / 111_000
                let target = CLLocationCoordinate2D(latitude: p.coordinate.latitude - shift,
                                                    longitude: p.coordinate.longitude)
                camera = .region(MKCoordinateRegion(center: target, latitudinalMeters: 900, longitudinalMeters: 900))
            }
        }
        .onChange(of: model.routeVersion) { _, _ in fitRoute() }
        .onChange(of: model.mode) { _, _ in fitRoute() }
        .onChange(of: radar.showRadars) { _, on in
            if on { Task { await radar.refresh(around: visibleCenter ?? center) } }
        }
        .onChange(of: model.isNavigating) { _, navigating in
            UIApplication.shared.isIdleTimerDisabled = navigating
            location.setNavigating(navigating)
            if navigating {
                followMode = true
                isSearching = false
                if let route = model.routes[model.mode]?.route { nav.start(route: route) }
                if let loc = location.location { followCamera(loc) }
                Task { await radar.refresh(around: center, radius: 7000) }
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

    // MARK: Disposición (vertical y horizontal)

    @ViewBuilder
    private var overlayLayout: some View {
        if landscape {
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 10) { topArea }
                        .frame(maxWidth: 460)
                    Spacer(minLength: 0)
                    controls
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(spacing: 10) { bottomArea }
                        .frame(maxWidth: 460)
                    Spacer(minLength: 0)
                    if model.isNavigating { speedometer }
                }
            }
        } else {
            VStack(spacing: 10) {
                topArea
                HStack {
                    Spacer()
                    controls
                }
                Spacer(minLength: 0)
                if model.isNavigating {
                    HStack {
                        speedometer
                        Spacer()
                    }
                }
                bottomArea
            }
        }
    }

    private var speedometer: some View {
        Speedometer(speed: location.location?.speed, limit: nav.nearbyHazard?.hazard.limit)
    }

    // MARK: Mapa (más oscuro, con nuestro tono azul marino)

    private var currentMapStyle: MapStyle {
        let elevation: MapStyle.Elevation = is3D ? .realistic : .flat
        return satellite ? .hybrid(elevation: elevation) : .standard(elevation: elevation, emphasis: .muted)
    }

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $camera) {
                userContent
                savedContent
                radarContent
                alertContent
                pinContent
                routeContent
            }
            .mapStyle(currentMapStyle)
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleCenter = context.region.center
                if radar.showRadars && !model.isNavigating {
                    Task { await radar.refresh(around: context.region.center) }
                }
            }
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

    // Contenido del mapa, dividido en piezas.

    @MapContentBuilder
    private var userContent: some MapContent {
        if let loc = location.location {
            Annotation("", coordinate: loc.coordinate, anchor: .center) {
                UserDot(store: location.headingStore, navigating: model.isNavigating)
            }
        }
        if let car = parking.parkedCar {
            Annotation("Coche aparcado", coordinate: car.coordinate, anchor: .bottom) {
                Button { model.selectedPlace = car.place } label: { ParkedCarPinView() }
            }
        }
    }

    /// Favoritos, Guardados y Sitios relevantes con su icono (como en Google Maps).
    @MapContentBuilder
    private var savedContent: some MapContent {
        if model.destination == nil && !model.isNavigating {
            ForEach(model.savedPins) { pin in
                Annotation(pin.item.name,
                           coordinate: CLLocationCoordinate2D(latitude: pin.item.latitude, longitude: pin.item.longitude),
                           anchor: .bottom) {
                    Button { model.selectedPlace = pin.item.place } label: { SavedPinView(list: pin.list) }
                }
            }
        }
    }

    /// Radares: visibles cuando quieras y siempre al navegar.
    @MapContentBuilder
    private var radarContent: some MapContent {
        if model.isNavigating || radar.showRadars {
            ForEach(radar.visible(near: visibleCenter ?? center)) { item in
                Annotation("", coordinate: item.coordinate, anchor: .bottom) {
                    RadarPinView(limit: item.maxSpeed)
                }
            }
        }
    }

    @MapContentBuilder
    private var alertContent: some MapContent {
        ForEach(alerts.active) { alert in
            Annotation("", coordinate: alert.coordinate, anchor: .bottom) {
                Button { selectedAlert = alert } label: { AlertPinView(kind: alert.kind) }
            }
        }
    }

    /// Dirección seleccionada (pulsación larga o búsqueda) y resultados.
    @MapContentBuilder
    private var pinContent: some MapContent {
        if model.destination == nil {
            if let pin = model.droppedPin {
                Marker(pin.name, systemImage: "mappin", coordinate: pin.coordinate)
                    .tint(.red)
            }
            ForEach(model.places) { place in
                Annotation(place.name, coordinate: place.coordinate, anchor: .bottom) {
                    Button { model.selectedPlace = place } label: {
                        RoundPin(icon: model.activeCategory?.icon ?? "mappin",
                                 color: model.activeCategory?.color ?? Color.red)
                    }
                }
            }
        }
    }

    /// Ruta: línea suave con halo y extremos redondeados.
    @MapContentBuilder
    private var routeContent: some MapContent {
        if let destination = model.destination {
            if let origin = model.origin {
                Marker(origin.name, systemImage: "circle.fill", coordinate: origin.coordinate)
                    .tint(.green)
            }
            Marker(destination.name, systemImage: "mappin", coordinate: destination.coordinate)
                .tint(.red)
            if let route = model.routes[model.mode]?.route {
                MapPolyline(route.polyline)
                    .stroke(Color.konnectBlue.opacity(0.28),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                if model.mode == .walking {
                    MapPolyline(route.polyline)
                        .stroke(Color(red: 0.42, green: 0.68, blue: 1.0),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round, dash: [0.5, 11]))
                } else {
                    MapPolyline(route.polyline)
                        .stroke(Color(red: 0.36, green: 0.64, blue: 1.0),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    // MARK: Gestos y cámara

    /// Dejar pulsado un punto del mapa abre su dirección.
    private func longPressGesture(_ proxy: MapProxy) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard !model.isNavigating, !isSearching else { return }
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

    private func currentHazards() -> [Hazard] {
        var list: [Hazard] = radar.visible(near: center, within: 3000).map { item in
            Hazard(id: "r\(item.id)",
                   coordinate: item.coordinate,
                   title: item.maxSpeed.map { "Radar · \($0) km/h" } ?? "Radar",
                   icon: "camera.fill",
                   color: Color.red,
                   limit: item.maxSpeed)
        }
        list += alerts.active.map { alert in
            Hazard(id: "a\(alert.id.uuidString)",
                   coordinate: alert.coordinate,
                   title: alert.kind.title,
                   icon: alert.kind.icon,
                   color: alert.kind.color,
                   limit: nil)
        }
        return list
    }

    private func handlePick(_ place: Place?, target: SearchTarget) {
        switch target {
        case .origin:
            Task { await model.setOrigin(place, userCoordinate: center) }
        case .destination:
            guard let place else { return }
            Task { await model.setDestination(place, userCoordinate: center) }
        }
    }

    // MARK: Búsqueda en el mapa

    private func startSearch() {
        searchText = ""
        isSearching = true
    }

    private func endSearch() {
        isSearching = false
        searchText = ""
    }

    private func pickFromSearch(_ place: Place) {
        endSearch()
        // El pin se quita solo al cerrar la ficha (no se queda en el mapa).
        model.droppedPin = place
        model.selectedPlace = place
    }

    private func submitSearch() {
        let query = searchText
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        model.addRecent(query)
        Task {
            let found = await model.query(query, near: center)
            model.places = found
            model.activeCategory = nil
            endSearch()
        }
    }

    // MARK: Zona superior

    @ViewBuilder
    private var topArea: some View {
        if model.isNavigating {
            NavigationBanner { showSteps = true }
            if let nearby = nav.nearbyHazard {
                HazardBanner(nearby: nearby)
            }
        } else if model.destination != nil {
            RoutePlannerCard(onEditOrigin: { searchTarget = .origin },
                             onEditDestination: { searchTarget = .destination })
        } else if isSearching {
            SearchOverlay(text: $searchText,
                          center: center,
                          onPick: { place in pickFromSearch(place) },
                          onSubmit: { submitSearch() },
                          onCancel: { endSearch() })
        } else {
            searchBar
            chips
            locationBanner
        }
    }

    /// La barra de búsqueda ocupa todo el ancho.
    private var searchBar: some View {
        Button { startSearch() } label: {
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

    /// Chips de categorías: llegan hasta los bordes y se difuminan al final.
    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let car = parking.parkedCar {
                    chip(title: "Mi coche", icon: "car.fill", tint: Color.indigo.opacity(0.7)) {
                        model.selectedPlace = car.place
                    }
                }
                ForEach(PlaceCategory.allCases) { category in
                    let active = model.activeCategory == category
                    chip(title: category.title, icon: category.icon,
                         tint: active ? category.color.opacity(0.6) : Color.glassTint,
                         iconColor: active ? Color.white : category.color) {
                        Task { await model.toggleCategory(category, near: center) }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, landscape ? 0 : -12)
        .horizontalFade(22)
    }

    private func chip(title: String, icon: String, tint: Color, iconColor: Color = Color.white,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(iconColor)
                Text(title).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .liquidGlass(in: Capsule(), tint: tint)
        }
        .buttonStyle(.pressable)
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
            VStack(spacing: landscape ? 10 : 12) {
                if model.isNavigating {
                    GlassCircleButton(icon: nav.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                      size: controlSize, active: !nav.isMuted) {
                        nav.isMuted.toggle()
                    }
                    GlassCircleButton(icon: followMode ? "arrow.up.left.and.arrow.down.right" : "location.north.fill",
                                      size: controlSize, active: !followMode) {
                        toggleFollow()
                    }
                    GlassCircleButton(icon: "megaphone.fill", size: controlSize) {
                        showReport = true
                    }
                } else {
                    GlassCircleButton(icon: "location.fill", size: controlSize) {
                        camera = .userLocation(fallback: .region(.madrid))
                    }
                    GlassCircleButton(icon: "square.3.layers.3d", size: controlSize, active: satellite) {
                        satellite.toggle()
                    }
                    GlassCircleButton(text: "3D", size: controlSize, active: is3D) {
                        toggle3D()
                    }
                    GlassCircleButton(icon: "camera.fill", size: controlSize, active: radar.showRadars) {
                        radar.showRadars.toggle()
                    }
                    GlassCircleButton(icon: "megaphone.fill", size: controlSize) {
                        showReport = true
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
        } else if !isSearching {
            PlacesPanel()
        }
    }
}
