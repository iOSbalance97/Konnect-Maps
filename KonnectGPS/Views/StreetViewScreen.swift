import SwiftUI
import MapKit
import WebKit

/// Street View: Apple Look Around (sin clave) o Google Street View (con tu clave).
struct StreetViewScreen: View {
    let title: String
    let coordinate: CLLocationCoordinate2D
    @Environment(\.dismiss) private var dismiss

    enum Provider: String {
        case apple = "Apple"
        case google = "Google"
    }

    @State private var provider: Provider = GoogleConfig.apiKey.isEmpty ? .apple : .google
    @State private var scene: MKLookAroundScene?
    @State private var sceneLoaded = false

    private var hasGoogleKey: Bool { !GoogleConfig.apiKey.isEmpty }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            content.ignoresSafeArea()
            topBar
                .padding(.horizontal, 12)
                .padding(.top, 6)
        }
        .preferredColorScheme(.dark)
        .task { await loadScene() }
    }

    @ViewBuilder
    private var content: some View {
        switch provider {
        case .apple:
            if let scene {
                LookAroundPreview(initialScene: scene)
            } else if sceneLoaded {
                unavailable("Apple Look Around no tiene imágenes en este punto.")
            } else {
                ProgressView().tint(Color.white)
            }
        case .google:
            GoogleStreetViewWeb(coordinate: coordinate, apiKey: GoogleConfig.apiKey)
        }
    }

    private var topBar: some View {
        GlassGroup(spacing: 8) {
            HStack(spacing: 10) {
                GlassCircleButton(icon: "xmark", size: 44) { dismiss() }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .liquidGlass(in: Capsule())
                Spacer()
                if hasGoogleKey {
                    Button {
                        provider = provider == .apple ? .google : .apple
                    } label: {
                        Text(provider == .apple ? "Apple" : "Google")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .liquidGlass(in: Capsule(), tint: Color.konnectBlue.opacity(0.7))
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private func unavailable(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "eye.slash").font(.system(size: 34))
            Text(message).multilineTextAlignment(.center)
            if hasGoogleKey {
                Text("Prueba con Google arriba a la derecha.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(Color.white)
        .padding(32)
    }

    private func loadScene() async {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        scene = try? await request.scene
        sceneLoaded = true
    }
}

/// Street View de Google mediante Maps Embed API (necesita la API activada en tu proyecto).
struct GoogleStreetViewWeb: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let apiKey: String

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        let location = String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
        let src = "https://www.google.com/maps/embed/v1/streetview?key=\(apiKey)&location=\(location)&fov=90"
        let html = """
        <html><head>
        <meta name='viewport' content='width=device-width, initial-scale=1'>
        <style>html,body{margin:0;height:100%;background:#000}iframe{border:0;width:100%;height:100%}</style>
        </head><body><iframe src='\(src)' allowfullscreen></iframe></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://www.google.com"))
    }
}
