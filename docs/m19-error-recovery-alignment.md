# M19 Error Recovery Alignment

Status: Complete static error recovery alignment.

M19 aligns recovery documentation with the support snapshot next-step model used by Android and iOS diagnostics.

## Alignment Rules

- Every recovery path should point to one primary next action.
- Normal users should see product copy, not raw JSON.
- Support snapshots should expose stable action codes through `nextStep`.
- Sensitive pairing and signing material must stay excluded.
- Scope branches such as video, contacts, files, reverse sync, delete propagation, and unattended iOS background sync remain outside the photo MVP.

## Updated File

- `docs/error-recovery-matrix.md`

The matrix now includes support snapshot alignment notes and a clear list of out-of-scope recovery branches.
