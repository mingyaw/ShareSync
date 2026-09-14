# M10 Support Triage

Status: Complete support triage tooling for the photo-only MVP.

M10 adds local tooling for validating and summarizing support snapshot JSON copied from Android or iOS during internal beta testing.

## Snapshot Inspection

Inspect a saved support snapshot:

```sh
python3 scripts/inspect-support-snapshot.py /path/to/support-snapshot.json
```

Or pipe JSON from stdin:

```sh
pbpaste | python3 scripts/inspect-support-snapshot.py
```

Use `--summary-only` when a clean support-note summary is enough:

```sh
python3 scripts/inspect-support-snapshot.py shared/fixtures/sample-support-snapshot-ios.json --summary-only
```

The default beta preflight also runs the inspector against Android and iOS support snapshot fixtures.

## What The Tool Checks

The inspector verifies:

- Required snapshot fields are present.
- `schemaVersion` is `1`.
- `type` is `sharesync_support_snapshot`.
- `platform` is `android` or `ios`.
- `generatedAt` is an RFC3339 timestamp.
- `nextStep` is present and valid for the snapshot platform.
- `sync` exists.
- Redaction markers confirm pairing token, request signature, and shared secret are excluded.
- Sensitive marker names do not appear outside the `redaction` section.

## Triage Summary

The summary highlights the parts most useful for internal beta support:

- Platform and app version.
- Current phase.
- Next-step action code.
- Transport mode.
- Local endpoint.
- Android server/request/sync counts.
- iOS binding/manifest/progress/import counts.

## Scope Reminder

Support triage remains limited to the photo-only MVP:

- Android-to-iOS photos only.
- Local network transfer only.
- iPhone Photos import only.
- No cloud relay, direct iCloud access, Apple ID handling, videos, contacts, files, reverse sync, delete propagation, or unattended iOS background sync.
