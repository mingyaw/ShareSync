# M32 First-Run Setup

Status: Complete source-code pass.

M32 adds a concise first-run path without creating a separate marketing screen.

## Android

- A one-time setup panel explains photo permission, same-network requirements, and iPhone QR pairing.
- Dismissing the panel stores only a local completion flag.
- The normal status and pairing screen remains available underneath.

## iOS

- A one-time setup panel explains local transfer, no cloud relay, and foreground operation.
- The primary setup action opens the Android QR scanner.
- Successful or manually restored pairing marks first-run setup complete.

Resetting app data or reinstalling the app intentionally shows setup again.
