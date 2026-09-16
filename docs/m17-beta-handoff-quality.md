# M17 Beta Handoff Quality

Status: Complete beta handoff quality pass.

M17 makes the source-code-backed beta handoff more useful for internal testing by including support snapshot triage evidence and explicitly recording deferred validation.

## Handoff Additions

`scripts/generate-beta-handoff.sh` now includes:

- Build identity: commit, branch, working tree state, platform versions, and transport.
- Release readiness output.
- Android and iOS support snapshot summaries.
- Deferred validation notes for real-device testing, QR-pinned HTTPS signoff, and store packaging.
- External artifact checksum rows when untracked artifacts are supplied.

## Scope Guardrails

- The handoff record is a source-code and local-check record.
- It does not claim real-device validation unless the caller passes a validation status that says so.
- It does not package, sign, notarize, upload, or distribute mobile artifacts.
- It must not include pairing tokens, shared secrets, request signatures, signing files, or local machine paths.
