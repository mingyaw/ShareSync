# M23 UX Copy And Flow

Status: Complete UX copy and flow pass.

M23 replaces remaining main-flow implementation words with user-facing language.

## Copy Direction

- `Fetch Manifest` becomes `Check Available Photos`.
- `Copy Sync Result` becomes `Copy Support Result`.
- `Copy Diagnostics` becomes `Copy Support Snapshot`.
- `Endpoint` becomes saved Android connection language in user-facing iOS copy.
- Pairing code language remains available for QR/manual fallback.

## Flow Direction

- Pair Android once.
- Check available photos.
- Sync all photos into iPhone Photos.
- Let iCloud Photos handle backup if the user has it enabled.
- Use support controls only when validating, recovering, or reporting an issue.

## Scope Reminder

M23 does not add videos, contacts, files, reverse sync, delete propagation, unattended iOS background sync, or any cloud relay.
