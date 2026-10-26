# Konnect GPS

App de mapas para iOS: interfaz Liquid Glass oscura (SwiftUI) con funcionalidad estilo Google Maps.

## Qué incluye
- **Explorar**: mapa con tono oscuro propio, búsqueda, categorías, capas, 3D y panel "Cerca de ti" plegable (se abre arrastrando).
- **Barra inferior** de globos circulares flotantes (Explorar, Guardados).
- **Perfil ("Tú")**: icono junto a la búsqueda; permisos de ubicación y clave de Google.
- **Ficha de lugar**: cómo llegar, guardar, compartir; con Google: valoración, horarios, fotos y reseñas.
- **Rutas**: coche, transporte y a pie, con giros paso a paso.

## Servicios (carpeta `Services`)
- `LocationService`: permisos, posición y rumbo.
- `PlacesService`: Google Places (si hay clave) con respaldo en Apple Maps.
- `RoutingService`: rutas con Apple Maps.
- `GeocodingService`: nombre de la ciudad.

## Liquid Glass
Se compila con Xcode 26 (runner `macos-26`). En iOS 26+ usa el cristal real del sistema; en iOS 17–25 usa un cristal oscuro equivalente.

## Google Maps
En la app: icono de perfil > Google Maps > pegar la clave de API (Places API (New)). La clave se guarda solo en el iPhone, no en el repositorio.

## Compilación
El proyecto Xcode se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) desde `project.yml`.
GitHub Actions compila un IPA sin firmar y lo publica en Releases (`latest`).
