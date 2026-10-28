import SwiftUI

/// Banner superior del guiado. Al tocarlo se abren los pasos de la ruta.
struct NavigationBanner: View {
    @EnvironmentObject var nav: NavigationEngine
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: nav.maneuverIcon)
                    .font(.system(size: 36, weight: .bold))
                    .frame(width: 52)
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
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "list.bullet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.white)
            .padding(16)
            .frame(maxWidth: .infinity)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

/// Aviso de radar o de otro conductor que tienes por delante.
struct HazardBanner: View {
    let nearby: NearbyHazard

    var body: some View {
        HStack(spacing: 12) {
            RoundPin(icon: nearby.hazard.icon, color: nearby.hazard.color, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(nearby.hazard.title).font(.subheadline.weight(.semibold))
                Text("a \(nearby.distance.distanceText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let limit = nearby.hazard.limit {
                LimitSign(limit: limit)
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous), tint: Color.red.opacity(0.35))
    }
}

/// Señal de límite de velocidad.
struct LimitSign: View {
    let limit: Int

    var body: some View {
        Text("\(limit)")
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.black)
            .frame(width: 42, height: 42)
            .background(Color.white, in: Circle())
            .overlay(Circle().stroke(Color.red, lineWidth: 4))
    }
}

/// Velocímetro (km/h).
struct Speedometer: View {
    let speed: Double?     // m/s
    let limit: Int?

    private var kmh: Int { Int((max(speed ?? 0, 0) * 3.6).rounded()) }
    private var isOver: Bool {
        if let limit { return kmh > limit }
        return false
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: -2) {
                Text("\(kmh)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("km/h")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isOver ? Color.white : Color.secondary)
            }
            .foregroundStyle(Color.white)
            .frame(width: 88, height: 88)
            .liquidGlass(in: Circle(), tint: isOver ? Color.red.opacity(0.55) : Color.glassTint)

            if let limit {
                LimitSign(limit: limit)
            }
        }
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
