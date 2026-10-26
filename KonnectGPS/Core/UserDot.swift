import SwiftUI

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Tu posición: un punto exacto (sin círculo de imprecisión).
struct UserDot: View {
    @ObservedObject var store: HeadingStore
    let navigating: Bool

    var body: some View {
        if navigating {
            // El mapa gira según tu rumbo: la flecha apunta siempre hacia arriba.
            Triangle()
                .fill(Color.konnectBlue)
                .frame(width: 26, height: 30)
                .overlay(Triangle().stroke(Color.white, lineWidth: 2.5))
                .shadow(color: Color.black.opacity(0.45), radius: 4, y: 2)
        } else {
            ZStack {
                Triangle()
                    .fill(Color.konnectBlue)
                    .frame(width: 12, height: 10)
                    .offset(y: -17)
                    .rotationEffect(.degrees(store.degrees))
                Circle().fill(Color.white).frame(width: 22, height: 22)
                Circle().fill(Color.konnectBlue).frame(width: 15, height: 15)
            }
            .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
        }
    }
}
