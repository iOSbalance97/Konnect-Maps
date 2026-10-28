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

/// Flecha de navegación (base de la flecha redondeada).
struct ArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.28))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Flecha suave: las esquinas se redondean con un contorno del mismo color.
struct SoftArrow: View {
    var color: Color = Color.konnectBlue

    var body: some View {
        ArrowShape()
            .fill(color)
            .overlay(
                ArrowShape()
                    .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            )
            .frame(width: 16, height: 18)
    }
}

/// Tu posición: un punto exacto (sin círculo de imprecisión).
struct UserDot: View {
    @ObservedObject var store: HeadingStore
    let navigating: Bool

    var body: some View {
        if navigating {
            // El mapa gira según tu rumbo: la flecha apunta siempre hacia arriba.
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
                SoftArrow()
            }
            .shadow(color: Color.black.opacity(0.4), radius: 6, y: 3)
        } else {
            ZStack {
                Triangle()
                    .fill(Color.konnectBlue)
                    .overlay(Triangle().stroke(Color.konnectBlue, style: StrokeStyle(lineWidth: 3, lineJoin: .round)))
                    .frame(width: 11, height: 9)
                    .offset(y: -18)
                    .rotationEffect(.degrees(store.degrees))
                Circle().fill(Color.white).frame(width: 22, height: 22)
                Circle().fill(Color.konnectBlue).frame(width: 15, height: 15)
            }
            .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
        }
    }
}
