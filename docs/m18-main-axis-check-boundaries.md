# M18 Main-Axis Check Boundaries

Status: Complete main-axis check boundary clarification.

M18 clarifies which local gates belong to source-code handoff and which gates require real devices.

## Local Source Gates

Use these checks before source-code handoff:

- `git diff --check`
- `python3 scripts/validate-fixtures.py`
- `bash scripts/test-support-snapshot-inspector.sh`
- `bash scripts/check-release-readiness.sh --transport signed-http`
- `bash scripts/check-beta-preflight.sh --transport signed-http`

These checks validate schemas, fixtures, support triage, release metadata, repo hygiene, and handoff output.

## Full Local Main-Axis Gate

Use this before a source-backed beta build when local tooling is available:

```sh
./scripts/check-m0.sh
```

This adds Swift tests, Android unit tests/Kotlin compile, and generic iOS build checks. It still does not replace physical-device validation.

## Real-Device Gates

These must be run manually on phones when validation resumes:

- Android MediaStore permission and photo scanning.
- Android local server and QR pairing on the actual network.
- iOS camera, local-network permission, Photos permission, and Photos import.
- iOS foreground/background interruption behavior.
- iCloud Photos observation after Photos import.
- QR-pinned HTTPS physical-device matrix before release readiness uses that transport.
