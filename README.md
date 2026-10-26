# Konnect GPS

App de mapas para iOS: interfaz Liquid Glass oscura (SwiftUI) con funcionalidad estilo Google Maps.

## Qué incluye
- **Explorar**: mapa con tono oscuro propio, búsqueda a todo el ancho, categorías, capas y 3D.
- **Lugares** (panel plegable, se abre arrastrando): Favoritos, Guardados y Sitios relevantes.
- **Barra inferior** de globos circulares flotantes: Explorar y Tú.
- **Pulsación larga** en el mapa: abre la dirección del punto.
- **Ficha de lugar**: cómo llegar, guardar en listas, Street View, compartir; con Google: valoración, horarios, fotos y reseñas.
- **Rutas A → B**: origen y destino editables, coche / transporte / a pie, lista de pasos.
- **Navegación guiada**: giro siguiente, voz, tiempo y distancia restantes, recálculo si te desvías.
- **Street View**: Apple Look Around o Google Street View.

## Servicios (carpeta `Services`)
- `LocationService`: permisos, precisión, posición y rumbo.
- `PlacesService`: Google Places (si hay clave) con respaldo en Apple Maps.
- `RoutingService`: rutas con Apple Maps.
- `NavigationEngine`: guiado paso a paso y voz.
- `GeocodingService`: ciudad y dirección de un punto.

## Liquid Glass
Se compila con Xcode 26 (runner `macos-26`). En iOS 26+ usa el cristal real del sistema; en iOS 17–25 usa un cristal oscuro equivalente.

## Google Maps
Perfil > Google Maps > pegar la clave. Activa en tu proyecto de Google Cloud: Places API (New) y, para Street View de Google, Maps Embed API. La clave se guarda solo en el iPhone.

## Compilación
El proyecto Xcode se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen) desde `project.yml` (`Config/Info.plist` añade la petición de ubicación precisa).
GitHub Actions compila un IPA sin firmar y lo publica en Releases (`latest`).
