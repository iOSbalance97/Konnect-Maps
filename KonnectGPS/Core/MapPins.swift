import SwiftUI

/// Pin redondo con icono (estilo Google Maps).
struct RoundPin: View {
    let icon: String
    let color: Color
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.45, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.95), lineWidth: 2))
            .shadow(color: Color.black.opacity(0.35), radius: 3, y: 2)
    }
}

struct SavedPinView: View {
    let list: PlaceList
    var body: some View {
        RoundPin(icon: list.icon, color: list.color == Color.yellow ? Color.orange : list.color, size: 32)
    }
}

struct RadarPinView: View {
    let limit: Int?
    var body: some View {
        VStack(spacing: 2) {
            RoundPin(icon: "camera.fill", color: Color.red, size: 32)
            if let limit {
                Text("\(limit)")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color.black)
                    .frame(width: 22, height: 22)
                    .background(Color.white, in: Circle())
                    .overlay(Circle().stroke(Color.red, lineWidth: 2))
            }
        }
    }
}

struct AlertPinView: View {
    let kind: AlertKind
    var body: some View {
        RoundPin(icon: kind.icon, color: kind.color, size: 34)
    }
}

struct ParkedCarPinView: View {
    var body: some View {
        RoundPin(icon: "car.fill", color: Color.indigo, size: 38)
    }
}
