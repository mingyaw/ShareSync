# M27 Adaptive Appearance

Status: Complete source-code pass.

M27 makes the native product UI follow light and dark system appearance without changing photo-transfer behavior.

## Android

- Screen colors now come from named resources instead of Kotlin constants.
- `values-night` provides dark background, surface, text, divider, and semantic status colors.
- Status and navigation bars follow the active appearance.
- The pairing QR keeps a white surface in both appearances for reliable scanning.

## iOS

- Brand and semantic colors use dynamic UIKit color providers.
- Primary, success, warning, error, and info colors preserve contrast in dark appearance.
- System grouped backgrounds and surfaces continue to follow iOS appearance automatically.

Real-device screenshot and contrast checks remain deferred.
