# M12 - Readiness Presenter Hardening

Status: Complete after M11 beta UX readiness completion on 2026-09-14.

Goal: make first-screen next-step guidance testable through platform readiness models instead of relying only on view-level switches.

## Scope Guardrails

- MVP remains Android-to-iOS photos only.
- No videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or cloud relay.
- Do not change the local transfer protocol in this slice.
- Real-device validation remains deferred until explicitly resumed.

## Tracks

### M12.1 Android Readiness Presenter

- [x] Add an explicit Android next-step enum.
- [x] Derive Android next-step guidance from the existing primary readiness action.
- [x] Update the Android screen to render the tested next-step state.

### M12.2 iOS Readiness Presenter

- [x] Add an explicit iOS next-step enum.
- [x] Derive iOS next-step guidance from the existing primary readiness action.
- [x] Update the iOS receive screen to render the tested next-step state.

### M12.3 Automated Coverage

- [x] Cover Android next-step states in runtime readiness tests.
- [x] Cover iOS next-step states in readiness tests.
- [x] Keep platform build/test and beta preflight gates green.

## Progress Log

### 2026-09-14 M12 Started

Added tested next-step presenter state:

- Android `AndroidPhotoSyncReadiness.nextStep` now drives the M11 next-step copy.
- iOS `PhotoSyncReadiness.nextStep` now drives the M11 next-step copy and icon selection.
- Existing readiness tests now verify the visible guidance state alongside primary actions and recovery guidance.
