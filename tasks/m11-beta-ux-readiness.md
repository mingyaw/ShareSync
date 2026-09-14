# M11 - Beta UX Readiness

Status: Complete after M10 support triage completion on 2026-09-14.

Goal: make the photo-only MVP first-run and paired flows easier to operate during beta testing without changing the local sync architecture.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Do not move diagnostic-only controls into the default happy path.
- Real-device validation remains deferred until explicitly resumed.

## Tracks

### M11.1 Android Home Guidance

- [x] Add a top-level next-step instruction to the Android pairing panel.
- [x] Drive the instruction from the existing Android runtime readiness state.
- [x] Keep endpoint, raw pairing payload, transport detail, and reset controls in Diagnostics.

### M11.2 iOS Home Guidance

- [x] Add a top-level next-step instruction to the iOS summary panel.
- [x] Drive the instruction from the same readiness state as the primary action.
- [x] Keep connection editing and diagnostic controls behind Settings.

### M11.3 Localization

- [x] Add English strings for new Android and iOS next-step guidance.
- [x] Add Traditional Chinese strings for new Android and iOS next-step guidance.
- [x] Keep format strings string-based to avoid Swift runtime format crashes.

### M11.4 Automated Gate

- [x] Keep repo hygiene, beta preflight, and platform build/test checks green.

## Progress Log

### 2026-09-14 M11 Started

Added product-focused next-step guidance:

- Android pairing panel now shows the next user action based on permission, server, manifest, and retry state.
- iOS summary panel now shows the next user action based on pairing, endpoint, Photos permission, manifest, and transfer state.
- English and Traditional Chinese copy were added for both platforms.
