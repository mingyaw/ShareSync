# M16 Platform-Specific Fixture Validation

Status: Complete platform-specific support snapshot fixture validation.

M16 makes fixture validation enforce the same Android and iOS `nextStep` split used by the support snapshot inspector. This keeps sample support snapshots aligned with the app-generated diagnostics before beta preflight or support triage tools run.

## Validation Behavior

`scripts/validate-fixtures.py` now checks:

- Android support snapshot fixtures only use Android next-step action codes.
- iOS support snapshot fixtures only use iOS next-step action codes.
- Existing schema validation still checks the shared support snapshot envelope.

The JSON schema intentionally keeps one shared enum because the top-level schema is platform-neutral. The fixture validator and support inspector add platform-aware validation where the full snapshot context is available.

## Scope Reminder

M16 remains limited to the photo-only MVP:

- Android-to-iOS photos only.
- Local network transfer only.
- iPhone Photos import only.
- No cloud relay.
- No direct iCloud API.
- No videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.
- Real-device validation remains deferred until explicitly resumed.
