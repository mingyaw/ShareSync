# M40 Paged Photo Manifest

Status: Complete source-code checkpoint.

Android returns bounded photo pages with `pageSize`, `hasMore`, and `nextCursor`. The embedded server reads `sinceCursor`, and iOS follows pages with a maximum-page guard, repeated-cursor stop condition, and asset-ID de-duplication. Existing Range streaming, partial-file resume, and storage preflight remain active for media bodies.
