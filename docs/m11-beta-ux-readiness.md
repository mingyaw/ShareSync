# M11 Beta UX Readiness

Status: Complete beta UX readiness pass for the photo-only MVP.

M11 makes the first screen behave more like a product flow and less like a protocol test panel. The app should answer three questions immediately:

- What state is this phone in?
- What should I do next?
- Where are the advanced controls if something goes wrong?

## Product Flow

### Android

Android remains the photo source and availability host.

The first screen prioritizes:

- Current photo sharing state.
- Pairing QR code when sharing is ready.
- A clear next-step instruction derived from the existing runtime readiness state.
- Photo list and sync history status for quick confidence.

Settings remain separate from diagnostics:

- Settings: photo permission and start/stop sharing.
- Diagnostics: endpoint, transport security, permissions, request activity, copied JSON, and local state reset.

### iOS

iOS remains the receiver and iCloud Photos gateway.

The first screen prioritizes:

- Pairing state.
- Manifest and transfer phase.
- Remaining photo count after a manifest exists.
- A clear next-step instruction derived from the same readiness decision used by the primary action.
- One primary action: scan, review connection, fetch manifest, allow Photos, or sync all photos.

Advanced connection and diagnostic tools remain behind the Settings disclosure.

## UX Rules

- Keep the first screen task-oriented.
- Keep endpoint, copied payload, raw sync JSON, and reset tools out of the default happy path.
- Use the same readiness model to drive visible guidance and primary button behavior.
- Preserve bilingual Traditional Chinese and English UI text.
- Do not introduce new sync content types in this milestone.

## Scope Reminder

M11 remains limited to the photo-only MVP:

- Android-to-iOS photos only.
- Local network transfer only.
- iPhone Photos import only.
- No cloud relay.
- No direct iCloud API.
- No videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.
- Real-device validation remains deferred until explicitly resumed.
