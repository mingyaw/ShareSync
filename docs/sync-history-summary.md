# Sync History Summary

Status: M3 cross-platform model baseline.

ShareSync uses sync history summaries to show recent photo sync outcomes without requiring users or testers to copy raw JSON.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `syncBatchId` | String? | Batch id reported by iOS or generated from the manifest cursor. |
| `targetDeviceId` | String | Device that received/imported the photos. |
| `recordedAt` | Date/time | Time the event was recorded locally. |
| `totalCount` | Int | Total photo items represented by the event. |
| `successfulCount` | Int | Synced plus skipped items. |
| `failedCount` | Int | Failed plus conflicted items. |
| `isComplete` | Boolean | True when `failedCount` is zero. |
| `needsRetry` | Boolean | True when `failedCount` is greater than zero. |

## Display Rules

- Show the newest events first.
- Show at least the latest three summaries in diagnostics/status areas.
- Prefer concise copy: batch id, done count, retry count.
- Keep raw JSON copy actions in diagnostics only.
- Do not treat a failed result-post event as proof that photos failed to import; the event status should remain visible in detailed diagnostics.
