# Konnect GPS

App de mapas para iOS: interfaz iOS (SwiftUI) con funcionalidad estilo Google Maps.

- **Explorar**: mapa, búsqueda, categorías, panel "Cerca de ti", capas, 3D.
- **Ficha de lugar**: cómo llegar, guardar, compartir, teléfono, web.
- **Navegación**: coche, transporte y a pie, con giros paso a paso.
- **Guardados** y **Tú**.

Datos de mapas y búsqueda: MapKit (Apple). Requiere iOS 17+.

## Cómo se compila
El proyecto Xcode se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de `project.yml`.
GitHub Actions (`.github/workflows/ios.yml`) lo genera y compila para el simulador en cada push.
El `.app` queda en Actions > ejecución > Artifacts.

## Pendiente
- Valoraciones, reseñas y fotos (Google Places API).
- Firma y TestFlight (requiere cuenta de Apple Developer).
