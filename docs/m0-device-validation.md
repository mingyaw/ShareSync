# M0 Device Validation

This checklist validates the current main path: Android exposes recent media over the local network, iOS pairs by QR, fetches the manifest, downloads media, and imports it into Photos.

## Devices

- Android primary phone with ShareSync debug build installed.
- iPhone with ShareSync debug build installed.
- Both devices on the same Wi-Fi network or Android hotspot.
- Android media permission granted.
- iOS camera, local network, and Photos permissions granted when prompted.

## Baseline Success Path

1. Open ShareSync on Android.
2. Tap `Grant media permission` if permission is missing.
3. Tap `Start M0 server`.
4. Confirm Android shows a manual endpoint and a QR code.
5. Open ShareSync on iPhone.
6. Tap `Scan Pairing QR`.
7. Scan the Android QR code.
8. Confirm iOS shows the Android host and port under `Pairing`.
9. Tap `Fetch Manifest`.
10. Confirm iOS shows photo/video counts and a cursor.
11. Tap `Download Next Item`.
12. Confirm status reaches completed/imported.
13. Open iOS Photos.
14. Confirm the item appears in the `ShareSync Backup` album.
15. Confirm the iOS ShareSync screen shows updated `Synced`, `Skipped`, and `Result Failed` counts.

Expected result: one Android media item is visible in iOS Photos and iCloud Photos can back it up through the normal iOS Photos pipeline.

## Foreground Full Manifest Transfer

1. Complete the baseline success path setup.
2. Tap `Fetch Manifest`.
3. Tap `Download Remaining`.
4. Keep the iOS app foregrounded until transfer and import finish.
5. Confirm iOS updates `Batch Progress`, `Batch Downloaded`, `Batch Failed`, and `Current File` while downloading.
6. Open iOS Photos.
7. Confirm imported media appears in the `ShareSync Backup` album.
8. Tap `Fetch Manifest` again.

Expected result: iOS imports every remaining manifest item it can download, the receive screen remaining count reaches `0`, and the next Android manifest excludes media reported as `synced` or `skipped`.

## Repeat Sync

1. Keep both apps open.
2. Tap `Fetch Manifest` again on iOS.
3. Tap `Download Next Item`.

Expected result: previously imported items are skipped by local state, and iOS chooses the next pending item.

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

## Android Port Fallback

1. Start another local process that occupies port `48291`, or start ShareSync once and verify conflict behavior during development.
2. Tap `Start M0 server` on Android.
3. Confirm Android endpoint shows the actual fallback port.
4. Scan the QR code on iOS.

Expected result: QR payload contains the actual bound port, and iOS can fetch `/v1/manifest` without manual editing.

## Network Interruption

1. Start a batch download on iOS.
2. Temporarily turn off Wi-Fi or move one device off the hotspot.
3. Restore the network.
4. Tap `Fetch Manifest`.
5. Tap `Download Next Item` or `Download 5 Items`.

Expected result: failed records remain retryable and completed records are not re-imported.

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

Post two sync result batches with different media ids.

Expected result: Android keeps completed media from both batches. If the same media id appears in a later batch, the later status replaces the earlier status.

After Android receives a sync result, fetch `/v1/manifest` again.

Expected result: media reported as `synced` or `skipped` does not appear in the next Android manifest. Media reported as `failed` remains eligible for retry.

## Permission Negative Cases

1. Deny Android media permission.
2. Confirm Android cannot start a useful media server until permission is granted.
3. Deny iOS Photos permission.
4. Confirm iOS surfaces a failed import state.
5. Deny iOS camera permission.
6. Confirm manual pairing payload remains available as fallback.

Expected result: errors are visible and the user can recover by granting permissions.

## Current M0 Gaps

- Android SHA-256 is calculated lazily before full media transfers and returned in `X-ShareSync-SHA256`.
- iOS duplicate prevention uses the app-local Android asset id to Photos local identifier mapping; deleting the iOS app removes that mapping.
- Full no-cloud relay privacy goal is preserved; no cloud intermediary is used by this flow.
