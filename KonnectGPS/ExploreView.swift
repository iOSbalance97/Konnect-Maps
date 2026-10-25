import SwiftUI
import MapKit

struct ExploreView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationManager

    @State private var camera: MapCameraPosition = .userLocation(fallback: .region(.madrid))
    @State private var showSearch = false
    @State private var pendingPick: Place?
    @State private var is3D = false
    @State private var satellite = false

    private var center: CLLocationCoordinate2D { location.location?.coordinate ?? .madrid }

    var body: some View {
        ZStack {
            map
            VStack(spacing: 10) {
                if model.isNavigating, let route = model.routes[model.mode]?.route {
                    NavigationBanner(route: route, userLocation: location.location)
                } else if !model.isNavigating {
                    if model.destination == nil {
                        searchBar
                        chips
                    }
                }
                HStack {
                    Spacer()
                    controls
                }
                Spacer()
                if let destination = model.destination {
                    RoutePanel(destination: destination)
                } else {
                    NearbyPanel(center: center)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
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

    // MARK: Mapa

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
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(model.activeCategory?.color ?? Color.red, in: Circle())
                                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                        }
                    }
                }
            }
        }
        .mapStyle(satellite ? .hybrid(elevation: is3D ? .realistic : .flat)
                            : .standard(elevation: is3D ? .realistic : .flat))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .ignoresSafeArea(edges: .top)
    }

    private func fitRoute() {
        guard let route = model.routes[model.mode]?.route else { return }
        let rect = route.polyline.boundingMapRect
        camera = .rect(rect.insetBy(dx: -rect.width * 0.25, dy: -rect.height * 0.6))
    }

    // MARK: Barra superior

    private var searchBar: some View {
        Button { showSearch = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                Text("Buscar aquí…").foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "mic.fill").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlaceCategory.allCases) { category in
                    Button {
                        Task { await model.toggleCategory(category, near: center) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon).foregroundStyle(category.color)
                            Text(category.title).font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(model.activeCategory == category ? category.color : Color.white.opacity(0.1),
                                                  lineWidth: model.activeCategory == category ? 1.5 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Botones laterales

    private var controls: some View {
        VStack(spacing: 10) {
            MapButton(icon: "location.fill") {
                camera = .userLocation(fallback: .region(.madrid))
            }
            MapButton(icon: "square.3.layers.3d") { satellite.toggle() }
            MapButton(text: "3D", active: is3D) { toggle3D() }
        }
    }

    private func toggle3D() {
        is3D.toggle()
        camera = is3D
            ? .camera(MapCamera(centerCoordinate: center, distance: 1200, heading: 0, pitch: 60))
            : .region(MKCoordinateRegion(center: center, latitudinalMeters: 3000, longitudinalMeters: 3000))
    }
}

struct MapButton: View {
    var icon: String? = nil
    var text: String? = nil
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let icon { Image(systemName: icon) }
                else if let text { Text(text).font(.headline) }
            }
            .frame(width: 48, height: 48)
            .foregroundStyle(active ? Color.konnectBlue : Color.white)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Panel "Cerca de ti"

struct NearbyPanel: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationManager
    let center: CLLocationCoordinate2D

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.places.isEmpty ? "Cerca de ti" : "Resultados").font(.title3.bold())
                    Text(model.places.isEmpty ? "Sitios populares en tu zona" : "\(model.places.count) lugares encontrados")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if !model.places.isEmpty {
                    Button("Limpiar") { model.clearResults() }.font(.subheadline)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if model.places.isEmpty {
                        ForEach(PlaceCategory.allCases) { category in
                            CategoryCard(category: category) {
                                Task { await model.toggleCategory(category, near: center) }
                            }
                        }
                    } else {
                        ForEach(model.places.prefix(12)) { place in
                            PlaceCard(place: place, distance: place.distance(from: location.location),
                                      category: model.activeCategory) {
                                model.selectedPlace = place
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.08)))
    }
}

struct CategoryCard: View {
    let category: PlaceCategory
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [category.color.opacity(0.9), category.color.opacity(0.35)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: category.icon).font(.system(size: 28)).foregroundStyle(.white)
                }
                .frame(height: 64)
                Text(category.title).font(.subheadline.weight(.semibold))
                Text("Ver cercanos").font(.caption).foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(width: 150, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct PlaceCard: View {
    let place: Place
    let distance: String?
    let category: PlaceCategory?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: category?.icon ?? "mappin.circle.fill")
                        .foregroundStyle(category?.color ?? Color.konnectBlue)
                    Spacer()
                    if let distance { Text(distance).font(.caption).foregroundStyle(.secondary) }
                }
                Text(place.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(place.categoryText).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 170, alignment: .leading)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
