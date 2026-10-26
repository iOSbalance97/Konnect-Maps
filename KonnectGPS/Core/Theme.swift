import SwiftUI

// MARK: - Colores

extension Color {
    static let konnectBlue = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let panel = Color(red: 0.07, green: 0.10, blue: 0.17)
    static let glassDark = Color(red: 0.03, green: 0.07, blue: 0.16)
    static let mapTint = Color(red: 0.02, green: 0.06, blue: 0.15)
    static var glassTint: Color { Color.glassDark.opacity(0.6) }
}

// MARK: - Liquid Glass
// En iOS 26+ (compilando con Xcode 26) usa el Liquid Glass real del sistema.
// En versiones anteriores usa un cristal oscuro equivalente.

#if compiler(>=6.2)
@available(iOS 26.0, *)
private func makeGlass(tint: Color, interactive: Bool) -> Glass {
    let base = Glass.regular.tint(tint)
    return interactive ? base.interactive() : base
}
#endif

private struct FallbackGlass<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(tint)
                }
            }
            .overlay {
                shape.stroke(
                    LinearGradient(colors: [Color.white.opacity(0.30), Color.white.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.35), radius: 14, y: 6)
    }
}

extension View {
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, tint: Color = Color.glassTint, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.modifier(FallbackGlass(shape: shape, tint: tint))
        }
        #else
        self.modifier(FallbackGlass(shape: shape, tint: tint))
        #endif
    }

    /// En iOS 26 las hojas ya son de cristal; antes de iOS 26 se pone un fondo oscuro.
    @ViewBuilder
    func darkSheetBackground() -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self
        } else {
            self.presentationBackground(Color.panel)
        }
        #else
        self.presentationBackground(Color.panel)
        #endif
    }
}

/// Agrupa elementos de cristal para que se fusionen/animen juntos en iOS 26.
struct GlassGroup<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - Componentes

struct GlassCircleButton: View {
    var icon: String? = nil
    var text: String? = nil
    var size: CGFloat = 50
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon).font(.system(size: size * 0.38, weight: .semibold))
                } else if let text {
                    Text(text).font(.system(size: size * 0.32, weight: .bold))
                }
            }
            .foregroundStyle(Color.white)
            .frame(width: size, height: size)
            .liquidGlass(in: Circle(),
                         tint: active ? Color.konnectBlue.opacity(0.75) : Color.glassTint,
                         interactive: true)
        }
        .buttonStyle(.plain)
    }
}

struct KonnectBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.02, green: 0.04, blue: 0.09),
                                Color(red: 0.04, green: 0.10, blue: 0.22)],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}
