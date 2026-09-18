# M42 Incremental Photo Indexing

Status: Complete source-code checkpoint.

Android manifest scans now accept a durable `media-v1` high-water cursor made
from MediaStore `DATE_MODIFIED` seconds plus the numeric media ID. The ID is the
tie-breaker for photos that share one modification timestamp. Subsequent syncs
can query only photos newer than the last completely acknowledged batch instead
of walking the full library again.

Incremental and pagination cursors have separate roles. `sinceCursor` remains
fixed for an entire sync, while `pageCursor` carries the snapshot upper bound
and pending offset. A photo added during pagination therefore waits for the next
sync instead of shifting or duplicating the active pages.

iOS stores the high-water cursor in the paired-device session. It advances only
after the manifest has no remaining transfer candidates and Android accepts the
sync-result post. A failed download, failed import, cancelled transfer, or failed
result post leaves the previous cursor intact. Resetting local sync history also
clears the cursor so the existing ledger and incremental boundary cannot drift.

M42 is source-tested. Deferred real-device validation must confirm Android OEM
MediaStore ordering and modification-time behavior before release signoff.
