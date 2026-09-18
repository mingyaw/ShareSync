# M43 Foreground Sync Orchestration

Status: Complete source-code checkpoint.

The iOS primary action now represents one foreground session: resolve the paired
Android endpoint, validate device identity, fetch every manifest page, reconcile
local PhotoKit mappings, download and resume pending photos, import them, return
item results, and advance the incremental cursor only after acknowledgement.
Cancellation and app backgrounding preserve retryable state. Automatic sync is
an opt-in foreground trigger and does not claim unattended iOS execution.
