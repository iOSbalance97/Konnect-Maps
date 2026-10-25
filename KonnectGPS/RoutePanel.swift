import SwiftUI
import MapKit

struct RoutePanel: View {
    @EnvironmentObject var model: AppModel
    let destination: Place

    var body: some View {
        VStack(spacing: 10) {
            if model.isNavigating { navigatingBar } else { options }
        }
        .padding(14)
        .background(Color.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.08)))
    }

    // Selección de modo
    private var options: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.name).font(.headline).lineLimit(1)
                    Text("Elige cómo ir").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { model.stopRoute() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                }
            }

            ForEach(RouteMode.allCases) { mode in
                row(for: mode)
            }

            Button(action: start) {
                Label("Iniciar", systemImage: "location.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.routes[model.mode] == nil)
        }
    }

    private func row(for mode: RouteMode) -> some View {
        let info = model.routes[mode]
        let selected = model.mode == mode
        return Button { model.mode = mode } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.icon).frame(width: 28)
                if let info {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.timeText).font(.headline)
                        Text(mode == .transit
                             ? info.distance.distanceText
                             : "\(info.distance.distanceText) · Llegada \(info.arrivalText)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text(model.isLoadingRoutes ? "Calculando…" : "\(mode.title): no disponible")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.white.opacity(selected ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Color.konnectBlue : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(info == nil)
    }

    // Durante la navegación
    private var navigatingBar: some View {
        HStack {
            if let info = model.routes[model.mode] {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.timeText).font(.title3.bold())
                    Text("\(info.distance.distanceText) · \(destination.name)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Button("Terminar", role: .destructive) { model.stopRoute() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
        }
    }

    private func start() {
        if model.mode == .transit {
            // Transporte público: Apple Maps gestiona el trayecto completo.
            destination.mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit
            ])
        } else {
            model.isNavigating = true
        }
    }
}

// MARK: - Banner de giro

struct NavigationBanner: View {
    let route: MKRoute
    let userLocation: CLLocation?

    private var steps: [MKRoute.Step] { route.steps.filter { !$0.instructions.isEmpty } }

    private func endPoint(of step: MKRoute.Step) -> CLLocation {
        let poly = step.polyline
        let coordinate = poly.points()[poly.pointCount - 1].coordinate
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    /// Primer paso cuyo final aún está a más de 30 m del usuario.
    private var current: (step: MKRoute.Step, distance: CLLocationDistance)? {
        guard let user = userLocation else {
            return steps.first.map { (step: $0, distance: $0.distance) }
        }
        for step in steps {
            let d = user.distance(from: endPoint(of: step))
            if d > 30 { return (step: step, distance: d) }
        }
        return nil
    }

    private func icon(for instruction: String) -> String {
        let t = instruction.lowercased()
        if t.contains("derecha") { return "arrow.turn.up.right" }
        if t.contains("izquierda") { return "arrow.turn.up.left" }
        return "arrow.up"
    }

    var body: some View {
        HStack(spacing: 14) {
            if let current {
                Image(systemName: icon(for: current.step.instructions)).font(.system(size: 34, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text(current.distance.distanceText).font(.title2.bold())
                    Text(current.step.instructions).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
            } else {
                Image(systemName: "flag.checkered").font(.system(size: 30))
                Text("Has llegado a tu destino").font(.headline)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.panel.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.08)))
    }
}
