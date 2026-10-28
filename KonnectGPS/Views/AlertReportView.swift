import SwiftUI
import CoreLocation

/// Avisar a otros conductores: policía, accidente, retención, obras...
struct AlertReportView: View {
    @EnvironmentObject var alerts: AlertsService
    @Environment(\.dismiss) private var dismiss
    let coordinate: CLLocationCoordinate2D

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 16) {
            Text("¿Qué has visto?").font(.title3.bold())
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AlertKind.allCases) { kind in
                    Button {
                        alerts.report(kind, at: coordinate)
                        dismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: kind.icon)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(kind.color)
                            Text(kind.title).font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 84)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                }
            }
            Text("Por ahora los avisos solo los ves tú en este iPhone. Se compartirán con otros conductores cuando se conecte un servidor.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .subtleGlassSheet()
    }
}

/// Detalle de un aviso: ¿sigue ahí?
struct AlertDetailView: View {
    @EnvironmentObject var alerts: AlertsService
    @Environment(\.dismiss) private var dismiss
    let alert: RoadAlert

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                RoundPin(icon: alert.kind.icon, color: alert.kind.color, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(alert.kind.title).font(.title3.bold())
                    Text("Avisado \(alert.createdAt.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Button {
                    alerts.confirm(alert)
                    dismiss()
                } label: {
                    choice("Sigue ahí", icon: "hand.thumbsup.fill", tint: Color.green)
                }
                .buttonStyle(.pressable)

                Button {
                    alerts.dismiss(alert)
                    dismiss()
                } label: {
                    choice("Ya no está", icon: "hand.thumbsdown.fill", tint: Color.red)
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(20)
        .presentationDetents([.height(190)])
        .presentationDragIndicator(.visible)
        .subtleGlassSheet()
    }

    private func choice(_ title: String, icon: String, tint: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .liquidGlass(in: Capsule(), tint: tint.opacity(0.55))
    }
}
