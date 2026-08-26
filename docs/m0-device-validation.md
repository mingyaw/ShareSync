# M0 Device Validation

This checklist validates the current main path: Android exposes recent photos over the local network, iOS pairs by QR, fetches the manifest, downloads photos, and imports them into Photos.

## Devices

- Android primary phone with ShareSync debug build installed.
- iPhone with ShareSync debug build installed.
- Both devices on the same Wi-Fi network or Android hotspot.
- Android photos permission granted.
- iOS camera, local network, and Photos permissions granted when prompted.

## Baseline Success Path

1. Open ShareSync on Android.
2. Tap `Grant photos permission` if permission is missing.
3. Tap `Start M0 server`.
4. Confirm Android shows a manual endpoint and a QR code.
5. Tap `Copy endpoint` on Android.
6. Open the copied endpoint from iPhone Safari if same-network reachability needs confirmation.
7. Confirm Android shows `Screen lock` as paused while the server is running.
8. Open ShareSync on iPhone.
9. Tap `Scan Pairing QR`.
10. Scan the Android QR code.
11. Confirm iOS shows the Android host and port under `Pairing`.
12. Tap `Fetch Manifest`.
13. Confirm iOS shows `Android Peer` as ready.
14. Confirm iOS shows a photo count and a cursor.
15. Confirm Android shows `Manifest photos` with the current pending photo count.
16. Tap `Download Next Item`.
17. Confirm status reaches completed/imported.
18. Open iOS Photos.
19. Confirm the item appears in the `ShareSync Backup` album.
20. Confirm the iOS ShareSync screen shows updated `Synced`, `Skipped`, and `Result Failed` counts.
21. Confirm Android shows the latest sync result summary.

Expected result: one Android photo is visible in iOS Photos, Android keeps showing the latest iOS sync result while the M0 server is running, and iCloud Photos can back it up through the normal iOS Photos pipeline.

Note: `Fetch Manifest`, media downloads, and sync result return require the pairing token from the Android QR/payload. Re-scan or paste a fresh payload if iOS shows a token rejection message.

## iOS Pairing Restore

1. Complete QR pairing once.
2. Force close ShareSync on iOS.
3. Reopen ShareSync on iOS.
4. Confirm the Android host, port, paired device name, and pairing status are restored without scanning again.
5. Tap `Fetch Manifest` while the same Android M0 server session is still running.

Expected result: iOS can reuse the persisted M0 pairing session after an app restart. If Android restarted the M0 server and generated a new token, iOS should show the token rejection message and require a fresh QR scan or pasted payload.

## Clear Stale iOS Pairing

Use this when Android restarted the M0 server and iOS still has the old endpoint or pairing token.

1. On iOS, tap `Clear Pairing`.
2. Confirm `Pairing` returns to `Manual`.
3. Start the Android M0 server.
4. Scan the fresh Android QR code, or paste the new manual pairing payload.
5. Tap `Fetch Manifest`.

Expected result: iOS forgets only the saved Android endpoint, device metadata, token, and pasted payload. Existing download/import mappings remain intact, so clearing pairing does not by itself make previously imported photos re-download.

## Foreground Full Manifest Transfer

1. Complete the baseline success path setup.
2. Tap `Fetch Manifest`.
3. Tap `Download Remaining`.
4. Keep the iOS app foregrounded until transfer and import finish.
5. Confirm iOS shows `Screen Lock` as paused while transfer is active.
6. Confirm iOS updates `Batch Progress`, `Batch Downloaded`, `Batch Failed`, and `Current File` while downloading.
7. Open iOS Photos.
8. Confirm imported photos appear in the `ShareSync Backup` album.
9. Tap `Fetch Manifest` again.

Expected result: iOS keeps the foreground transfer awake, imports every remaining manifest photo it can download, the receive screen remaining count reaches `0`, and the next Android manifest excludes photos reported as `synced` or `skipped`.

Keep the Android M0 screen open during the transfer and confirm Android `Screen lock` remains paused.

Expected result: Android continues updating the sync result summary even when the transfer takes longer than one minute.

## Repeat Sync

1. Keep both apps open.
2. Tap `Fetch Manifest` again on iOS.
3. Tap `Download Next Item`.

Expected result: previously imported items are skipped by local state, and iOS chooses the next pending item.

## Reset Local Test State

Use this only when rerunning M0 validation from a clean ShareSync state.

1. On iOS, tap `Reset Local Sync State`.
2. Confirm the receive screen returns to the idle manifest state.
3. On Android, tap `Clear sync result`.
4. Tap `Fetch Manifest` on iOS again.

Expected result: ShareSync local transfer mappings and latest result JSON are cleared on iOS, Android clears its persisted iOS result report, and the next manifest/result cycle is rebuilt from the current devices. Imported photos remain in iOS Photos and are not deleted by the reset controls.

Note: use `Clear Pairing` instead when only the remembered Android endpoint or pairing token is stale.

## Deleted Imported Photo

1. Delete one imported ShareSync item from iOS Photos.
2. Open ShareSync on iOS.
3. Tap `Fetch Manifest`.
4. Tap `Download Next Item` or `Download Remaining`.

Expected result: the item count includes `Missing`, iOS reports that item as failed to Android, and the item is eligible to download/import again.

## App Restart Resume

1. Download an item on iOS.
2. Force close ShareSync before or immediately after import.
3. Reopen ShareSync.
4. Tap `Fetch Manifest`.
5. Tap `Download Next Item`.

Expected result: downloaded-but-not-imported items continue into Photos import; imported items are not duplicated.

After a successful import, confirm the app does not depend on the temporary downloaded file anymore.

Expected result: imported items remain tracked by Photos local identifier, the paired Android session is restored, and only downloaded-but-not-imported items need app temp files for resume.

## Android Port Fallback

1. Start another local process that occupies port `48291`, or start ShareSync once and verify conflict behavior during development.
2. Tap `Start M0 server` on Android.
3. Confirm Android endpoint shows the actual fallback port.
4. Tap `Copy endpoint` and confirm the copied URL uses the actual fallback port.
5. Scan the QR code on iOS.

Expected result: QR payload contains the actual bound port, and iOS shows `Android Peer` before fetching `/v1/manifest` without manual editing.

## Network Interruption

1. Start a batch download on iOS.
2. Temporarily turn off Wi-Fi or move one device off the hotspot.
3. Restore the network.
4. Tap `Fetch Manifest`.
5. Tap `Download Next Item` or `Download 5 Items`.

Expected result: iOS retries one transient download interruption automatically. If the connection is still unavailable, failed records remain retryable, completed records are not re-imported, and iOS shows `SS-NET-002` in `Last Failure`.

For development builds with a persisted partial media file, confirm the next request includes a `Range` header such as `bytes=<downloadedBytes>-`.

Expected result: iOS shows `Partial` greater than `0` before retry, Android returns `206 Partial Content`, iOS combines the partial file with the response body, verifies the final checksum, and imports only the completed photo.

During development builds, simulate a `206 Partial Content` response with a missing or mismatched `Content-Range`.

Expected result: iOS rejects the partial response, marks the photo failed with `SS-MEDIA-003`, and leaves the item eligible for retry.

During Android local API validation, request an invalid range such as `bytes=999999999-` for a smaller media item.

Expected result: Android returns `416 Range Not Satisfiable`, includes `Content-Range: bytes */<totalSize>`, and returns `SS-REQ-416`.

## iOS Foreground Interruption

1. Start a `Download Remaining` transfer on iOS.
2. Press the Home indicator/button or lock the iPhone manually while transfer is active.
3. Reopen ShareSync.
4. Confirm the receive screen shows a paused transfer message.
5. Tap `Fetch Manifest`.
6. Tap `Download Next Item`, `Download 5 Items`, or `Download Remaining`.

Expected result: ShareSync pauses foreground-only transfer when iOS leaves the foreground, keeps completed items, and retries remaining items without duplicating imported Photos assets.

## Hash Mismatch Retry

1. During development, simulate or force a bad first response body for one photo while keeping the manifest hash unchanged.
2. Let the next response return the correct photo bytes.
3. Start the iOS download.

Expected result: iOS retries the checksum mismatch once, imports the photo if the retry matches, and does not mark the item failed.

## Manual Stop And Retry

1. Complete the baseline success path setup.
2. Tap `Download Remaining`.
3. Wait until `Batch Progress` advances.
4. Tap `Stop Transfer`.
5. Tap `Fetch Manifest`.
6. Tap `Download Next Item`, `Download 5 Items`, or `Download Remaining`.

Expected result: ShareSync shows the transfer stopped message, keeps completed items, and retries remaining or in-progress items without duplicating imported Photos assets.

## Sync Result JSON

The iOS app persists the latest M0 sync result as app support data:

```text
ShareSync/latest-sync-result.json
```

Expected result: terminal media records are written as shared `SyncResult` JSON with `synced`, `skipped`, or `failed` statuses.

The iOS app also attempts to post the same result to Android:

```http
POST /v1/sync/result
```

Expected result: Android accepts valid M0 sync result JSON with HTTP `202 Accepted`, persists the latest result under app files data, and shows the latest batch summary on the Android M0 screen.
If a failed result is present, Android should show the latest failed error code in the sync result summary.

Force close and reopen Android ShareSync before starting the M0 server again.

Expected result: Android still shows the latest persisted sync result summary, and `Clear sync result` is available when a result exists.

Post two sync result batches with different media ids.

Expected result: Android keeps completed media from both batches. If the same media id appears in a later batch, the later status replaces the earlier status.

After Android receives a sync result, fetch `/v1/manifest` again.

Expected result: photos reported as `synced` or `skipped` do not appear in the next Android manifest. Photos reported as `failed` remain eligible for retry.

## Permission Negative Cases

1. Deny Android photos permission.
2. Confirm Android cannot start a useful media server until permission is granted.
3. Deny iOS Photos permission.
4. Confirm iOS shows `Photos Access` as denied or restricted.
5. Tap `Download Next Item`, `Download 5 Items`, or `Download Remaining`.
6. Confirm iOS stops before downloading and shows a Photos access failure message.
7. Deny iOS camera permission.
8. Confirm manual pairing payload remains available as fallback.

Expected result: errors are visible before unnecessary transfer work, and the user can recover by granting permissions.

When a media endpoint fails, confirm the iOS receive screen shows `Last Failure` with the server error code and file name.

## Low Storage

1. Fill the iPhone simulator or device storage close to full, or use a large Android photo set on a low-storage test device.
2. Tap `Fetch Manifest`.
3. Tap `Download Next Item` or `Download Remaining`.

Expected result: iOS marks the photo as failed with `SS-STORE-001`, shows that code in `Last Failure`, and reports the failed record back to Android.

## Current M0 Gaps

- Android SHA-256 is calculated lazily before full media transfers and returned in `X-ShareSync-SHA256`.
- iOS can resume from persisted partial media state with `Range`; foreground M0 transfer progress still depends on the app remaining open.
- iOS duplicate prevention uses the app-local Android asset id to Photos local identifier mapping; deleting the iOS app removes that mapping.
- M0 reset controls clear ShareSync local sync state only; they do not inspect or remove existing Photos library items.
- Full no-cloud relay privacy goal is preserved; no cloud intermediary is used by this flow.
