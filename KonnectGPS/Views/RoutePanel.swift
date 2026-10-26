import SwiftUI
import MapKit

// MARK: - Tarjeta superior: de dónde a dónde

struct RoutePlannerCard: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    let onEditOrigin: () -> Void
    let onEditDestination: () -> Void

    private var userCoordinate: CLLocationCoordinate2D { location.location?.coordinate ?? .madrid }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 5) {
                Image(systemName: "circle.fill").font(.system(size: 10)).foregroundStyle(Color.green)
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color.white.opacity(0.4)).frame(width: 3, height: 3)
                }
                Image(systemName: "mappin.circle.fill").font(.system(size: 18)).foregroundStyle(Color.red)
            }

            VStack(spacing: 6) {
                fieldRow(caption: "Origen",
                         text: model.origin?.name ?? "Mi ubicación",
                         action: onEditOrigin)
                Divider().overlay(Color.white.opacity(0.15))
                fieldRow(caption: "Destino",
                         text: model.destination?.name ?? "",
                         action: onEditDestination)
            }

            VStack(spacing: 10) {
                Button {
                    Task { await model.swapEndpoints(userCoordinate: userCoordinate) }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.10), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.pressable)

                Button { model.stopRoute() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.10), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func fieldRow(caption: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                Text(caption).font(.caption2).foregroundStyle(.secondary)
                Text(text).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Panel inferior: opciones de ruta

struct RoutePanel: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var location: LocationService
    let destination: Place
    @Binding var showSteps: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
    }

    private var currentInfo: RouteInfo? { model.routes[model.mode] }
    private var startTitle: String {
        model.origin == nil ? "Iniciar" : "Iniciar desde mi ubicación"
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(RouteMode.allCases) { mode in
                row(for: mode)
            }

            HStack(spacing: 10) {
                if currentInfo?.route != nil {
                    Button { showSteps = true } label: {
                        Label("Pasos", systemImage: "list.bullet")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 18)
                            .frame(height: 50)
                            .liquidGlass(in: Capsule())
                    }
                    .buttonStyle(.pressable)
                }

                Button(action: start) {
                    Label(startTitle, systemImage: "location.fill")
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .liquidGlass(in: Capsule(), tint: Color.konnectBlue.opacity(0.85))
                }
                .buttonStyle(.pressable)
                .disabled(currentInfo == nil)
                .opacity(currentInfo == nil ? 0.5 : 1)
            }
        }
        .padding(16)
        .liquidGlass(in: shape)
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
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(model.isLoadingRoutes ? "Calculando…" : "\(mode.title): no disponible")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.white)
            .padding(12)
            .background(Color.white.opacity(selected ? 0.14 : 0.05),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? Color.konnectBlue : Color.clear, lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(info == nil)
    }

    private func start() {
        if model.mode == .transit {
            // Transporte público: Apple Maps gestiona el trayecto completo.
            destination.mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit
            ])
        } else {
            Task { await model.beginNavigation(userCoordinate: location.location?.coordinate ?? .madrid) }
        }
    }
}

// MARK: - Lista de pasos

struct RouteStepsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var steps: [MKRoute.Step] {
        (model.routes[model.mode]?.route?.steps ?? []).filter { !$0.instructions.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    HStack(spacing: 12) {
                        Image(systemName: maneuverSymbol(for: step.instructions))
                            .frame(width: 28)
                            .foregroundStyle(Color.konnectBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.instructions)
                            if step.distance > 0 {
                                Text(step.distance.distanceText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pasos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .darkSheetBackground()
    }
}
