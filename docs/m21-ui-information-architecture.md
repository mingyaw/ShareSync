# M21 UI Information Architecture

Status: Complete UI information architecture pass.

M21 reshapes the photo-only MVP screens around the user's flow instead of protocol details.

## Android

The Android screen is organized as:

- Photo Status: current state, next action, photo count, and recent sync evidence.
- Share Photos: primary actions for permission, sharing, and stopping.
- Pair iPhone: QR code and pairing instruction.
- Connection Settings: network address, permissions, screen lock, transport, and copy actions.
- Support: request activity, support result, support snapshot, and reset controls.

## iOS

The iOS screen already uses a product-led structure:

- Header.
- Transfer summary.
- Primary action or pairing action.
- Advanced settings for saved Android, status, and support.

M21 keeps that structure and aligns the naming with the Android screen.

## Guardrails

- Main screens should lead with photo status and the next user action.
- Diagnostic JSON and reset controls belong in support or advanced sections.
- Manual connection details should not be the first thing a normal user sees.
- MVP remains Android-to-iOS photos only.
