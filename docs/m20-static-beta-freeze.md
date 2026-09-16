# M20 Static Beta Freeze

Status: Complete static beta freeze checkpoint.

M20 is a source-code freeze checkpoint for the photo-only MVP before the next real-device validation pass. It does not claim store readiness or physical-device signoff.

## Completed Static Gates

- Product scope remains Android-to-iOS photos only.
- Local transfer remains direct local network transfer without a cloud relay.
- iPhone Photos import remains the iCloud backup bridge.
- Support snapshot format is redacted and platform-aware.
- Support snapshot inspector has positive and negative regression tests.
- Fixture validation enforces platform-specific support snapshot next-step values.
- Beta handoff output includes support snapshot summaries and deferred validation notes.
- Error recovery documentation is aligned with next-step support evidence.

## Required Before Calling This A Device-Validated Beta

- Run Android and iPhone physical-device validation.
- Record M2/M4 physical-device results when applicable.
- Confirm imported photos appear in iPhone Photos and iCloud Photos sync is user-enabled.
- Confirm foreground interruption and resume behavior on a real iPhone.
- Package unsigned/signed artifacts outside Git and record checksums in a handoff record.
- Push the source branch after final review when repository access permits.

## Current Static Command Set

```sh
python3 scripts/validate-fixtures.py
bash scripts/test-support-snapshot-inspector.sh
bash scripts/check-beta-preflight.sh --transport signed-http
```

Use `./scripts/check-m0.sh` for the fuller local gate before sharing a source-code-backed build.
