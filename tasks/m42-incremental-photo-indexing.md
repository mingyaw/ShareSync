# M42 - Incremental Photo Indexing

Status: Complete on 2026-09-18.

- [x] Add timestamp-and-ID MediaStore scan boundaries.
- [x] Separate durable `sinceCursor` from ephemeral `pageCursor`.
- [x] Freeze the page snapshot while a manifest is being collected.
- [x] Persist the acknowledged cursor with the paired Android device.
- [x] Advance only after terminal photo state and successful result return.
- [x] Clear the cursor when local sync history is reset.
- [x] Preserve legacy page-cursor request compatibility.
- [x] Add Android and Swift regression coverage.
- [ ] Validate MediaStore cursor ordering on physical Android devices (deferred).
