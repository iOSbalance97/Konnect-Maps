import SwiftUI

/// Banner superior del guiado: siguiente giro y distancia.
struct NavigationBanner: View {
    @EnvironmentObject var nav: NavigationEngine

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: nav.maneuverIcon)
                .font(.system(size: 36, weight: .bold))
                .frame(width: 52)
                .foregroundStyle(Color.white)
            VStack(alignment: .leading, spacing: 2) {
                if nav.hasArrived {
                    Text("Has llegado").font(.title2.bold())
                } else {
                    Text(nav.distanceToManeuver.distanceText).font(.title.bold())
                }
                Text(nav.maneuverText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// Barra inferior del guiado: llegada, tiempo y distancia restantes.
struct NavigationBottomBar: View {
    @EnvironmentObject var nav: NavigationEngine
    @EnvironmentObject var model: AppModel

    private var arrival: String {
        Date().addingTimeInterval(nav.remainingTime).formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 18) {
            stat(value: arrival, caption: "llegada")
            stat(value: nav.remainingTime.durationText, caption: "restante")
            stat(value: nav.remainingDistance.distanceText, caption: "distancia")
            Spacer(minLength: 4)
            Button { model.stopRoute() } label: {
                Text(nav.hasArrived ? "Listo" : "Terminar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .liquidGlass(in: Capsule(), tint: Color.red.opacity(0.7))
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private func stat(value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline)
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
