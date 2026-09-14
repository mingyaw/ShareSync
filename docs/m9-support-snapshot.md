# M9 Support Snapshot

Status: Complete support snapshot standard for the photo-only MVP.

M9 standardizes copied diagnostics into a redacted JSON support snapshot so internal beta reports can be collected consistently from Android and iOS.

## Snapshot Contract

Support snapshots use `shared/schemas/support-snapshot.schema.json`.

Required top-level fields:

- `schemaVersion`: currently `1`.
- `type`: `sharesync_support_snapshot`.
- `platform`: `android` or `ios`.
- `generatedAt`: RFC3339 timestamp.
- `appVersion`: user-visible app version.
- `phase`: current user-facing app phase.
- `nextStep`: machine-readable next user action.
- `transport`: current local transport mode.
- `sync`: latest sync counts or status.
- `redaction`: explicit confirmation that sensitive fields are excluded.

Optional fields can include endpoint, binding, permission, platform-specific, and latest-request details.

## Redaction Rules

Support snapshots must never include:

- Pairing token.
- Request signature.
- Shared secret.
- Private signing material.
- Photos file bytes.
- Apple ID, iCloud credentials, or iCloud Drive data.

The snapshot may include local endpoint information because local IP/port data is needed to diagnose two-phone pairing and network mismatch problems during internal beta testing.

## Platform Behavior

Android `Copy diagnostics` now copies support snapshot JSON with:

- App version/build.
- Server state.
- Endpoint.
- Transport mode.
- Next-step action code.
- Media and notification permission state.
- Pending photo count.
- Latest request endpoint/status.
- Latest sync batch and result counts.

iOS `Copy diagnostics` now copies support snapshot JSON with:

- App version/build.
- Pairing/binding state.
- Endpoint display.
- Next-step action code.
- Photos permission state.
- Screen-lock status.
- Manifest and batch progress.
- Sync result return status.
- Photo transfer/import counts.

## Validation

Fixtures:

- `shared/fixtures/sample-support-snapshot-android.json`
- `shared/fixtures/sample-support-snapshot-ios.json`

Run:

```sh
python3 scripts/validate-fixtures.py
```

The full beta preflight also covers fixture validation when run with `--full`.
