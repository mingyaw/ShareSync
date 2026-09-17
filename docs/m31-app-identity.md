# M31 App Identity

Status: Complete source-code pass.

M31 introduces a recognizable product identity based on two phones and a local sync symbol.

- The iOS project now contains an AppIcon asset catalog with a 1024 px source image.
- The icon can be regenerated with `swift scripts/generate-app-icon.swift OUTPUT_PNG`.
- The Android adaptive foreground uses the same two-phone sync concept.
- The design avoids text and keeps strong contrast at small sizes.

Real-device home-screen appearance and all platform mask variants remain deferred.
