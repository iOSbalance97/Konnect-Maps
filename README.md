# Konnect GPS

App de mapas para iOS: interfaz Liquid Glass oscura (SwiftUI) con funcionalidad estilo Google Maps.

## Qué incluye
- **Explorar**: mapa con tono oscuro propio, búsqueda a todo el ancho con recientes y sugerencias, categorías, capas, 3D, radares.
- **Lugares** (panel plegable, se abre arrastrando): Recientes, Favoritos, Guardados y Sitios relevantes (también en el mapa con su icono).
- **Globo inferior** único: alterna entre el mapa y Tú.
- **Pulsación larga** en el mapa: abre la dirección del punto.
- **Ficha de lugar**: cómo llegar, guardar en listas, Street View, compartir; con Google: valoración, horarios, fotos y reseñas.
- **Rutas A → B** y **navegación guiada** con voz, velocímetro, radares y avisos de conductores. Tocar el banner abre los pasos.
- **Coche aparcado**: se guarda al desconectar Bluetooth/CarPlay o al alejarte del último punto conectado.
- **Vista horizontal** adaptada.

## Servicios (carpeta `Services`)
LocationService, PlacesService, RoutingService, NavigationEngine, GeocodingService,
ParkingService, RadarService (OpenStreetMap) y AlertsService (avisos locales).

## CarPlay
Código preparado en `CarPlay/` (fuera de la compilación). Ver `CarPlay/LEEME.md`.

## Liquid Glass
Se compila con Xcode 26 (runner `macos-26`). En iOS 26+ usa el cristal real del sistema; en iOS 17–25 un cristal oscuro equivalente.

## Compilación
XcodeGen genera el proyecto desde `project.yml`. GitHub Actions compila un IPA sin firmar y lo publica en Releases (`latest`).
