# CarPlay en Konnect GPS

El código está listo en `CarPlaySceneDelegate.swift`, pero **no se compila todavía**
porque CarPlay no funciona sin:

1. Cuenta de pago de Apple Developer.
2. El permiso (entitlement) **CarPlay Maps** (`com.apple.developer.carplay-maps`),
   que Apple concede bajo petición en developer.apple.com/carplay.
3. Firmar la app con ese permiso (no se puede con un Apple ID gratuito / sideloading).

## Cómo activarlo cuando lo tengas
1. Mueve `CarPlay/CarPlaySceneDelegate.swift` a `KonnectGPS/CarPlay/`.
2. Crea `Config/KonnectGPS.entitlements` con la clave `com.apple.developer.carplay-maps = true`
   y añade `CODE_SIGN_ENTITLEMENTS: Config/KonnectGPS.entitlements` en `project.yml`.
3. En `Config/Info.plist` añade la escena de CarPlay:

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key><true/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array><dict>
            <key>UISceneConfigurationName</key><string>CarPlay</string>
            <key>UISceneDelegateClassName</key><string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
        </dict></array>
    </dict>
</dict>
```
4. Compila y pásame el log: es código sin probar y puede necesitar retoques.

## Mientras tanto
La detección de **coche aparcado** ya reconoce CarPlay (audio del coche) y Bluetooth
sin necesitar este permiso.
